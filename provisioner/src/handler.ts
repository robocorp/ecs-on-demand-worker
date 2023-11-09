import { APIGatewayProxyEventV2, APIGatewayProxyResultV2, EventBridgeEvent } from 'aws-lambda';
import { parseEnvVariable } from './utils';
import { Command } from './api-constants';
import {
  getProvisionerConfiguration,
  getClusterConfiguration,
  getEcsProvisioner,
} from './dependencies';
import { HmacError, validateHmac } from './hmac';
import {
  withValidation,
  onValidationFailureFatal,
  startCommandSchemaV1,
  ValidationError,
  apiGwRequestEventSchema,
} from './validation';

const buildResponse = (
  statusCode: number,
  message: string | undefined = undefined,
): APIGatewayProxyResultV2 => {
  return {
    statusCode,
    body: JSON.stringify({
      message,
    }),
  };
};

export const handler = async (
  rawEvent: APIGatewayProxyEventV2,
): Promise<APIGatewayProxyResultV2> => {
  try {
    /**
     * Validate that the event from AWS matches our expectations and contains
     * all the expected information. The validation routine throws on failure,
     * so we bail out immediately on errors.
     */
    const validatedEvent = withValidation(
      apiGwRequestEventSchema,
      rawEvent,
      onValidationFailureFatal,
    );

    /**
     * Read the provisioner configuration from AWS Secrets Manager. The terraform
     * project is responsible for putting this configuration in place.
     *
     * This configuration contains the preshared secret, DO NOT LOG.
     */
    const provisionerConfiguration = await getProvisionerConfiguration(
      parseEnvVariable('WORKER_PROVIDER_CONFIGURATION_SECRET'),
    );

    /**
     * Validate request HMAC signature and timestamp. We want to do this as
     * early as possible to stop processing potentially malicious requests.
     */
    validateHmac(validatedEvent, provisionerConfiguration.secret); // throws on failure

    /**
     * Parse body of the message so we can peek inside.
     */
    const body = JSON.parse(validatedEvent.body);

    if (body.type === Command.start) {
      /**
       * Validate that the body contains expected structure.
       */
      const validatedRequest = withValidation(startCommandSchemaV1, body, onValidationFailureFatal);

      /**
       * Fetch cluster configuration required for provisioning to ECS.
       * We could also have multiple clusters and dispatch the workloads
       * based on some criteria.
       */
      const clusterCfg = await getClusterConfiguration(
        provisionerConfiguration.clusterConfigParameterArn,
      );

      /**
       * Dispatch the workload to our ECS cluster.
       */
      const ecsProvisioner = getEcsProvisioner(clusterCfg);
      await ecsProvisioner.provisionWorker({
        /**
         * Pass information from the Control Room request.
         */
        linkToken: validatedRequest.runtimeLinkToken,
        workspaceId: validatedRequest.workspaceId,
        workerId: validatedRequest.runtimeId,

        /**
         * This controls which docker image gets started.
         * This request could easily be augmented with e.g. amount of
         * resources allocated for the task or other parameters passed
         * to the task definition.
         */
        imageUri: `${provisionerConfiguration.ecrRepositoryUrl}:${parseEnvVariable(
          'ECR_IMAGE_TAG',
        )}`,
      });

      return buildResponse(200);
    }

    if (body.type === Command.stop) {
      /**
       * This is important for VMs but almost unnecessary with typical
       * Linux containers:
       *  - Control Room terminates the run via a command to the agent delivered
       *    over the application level control channel (outside
       *    this provisioner).
       *  - Agent shuts down after a single run finishes, and the container
       *    shuts down once agent shuts down.
       *
       * We return 200 OK to avoid CR doing unnecessary retries.
       */
      console.log('Stop command: not implemented', body);
      return buildResponse(200);
    }

    if (body.type === Command.status) {
      /**
       * Status command is specified but currently not used by the Control Room.
       * We'd need to implement local bookkeeping or query from ECS to provide any
       * meaningful status, but for now just report everything is OK.
       */
      return buildResponse(
        200,
        JSON.stringify({
          version: 1,
          status: 'OK',
        }),
      );
    }
  } catch (err) {
    console.error('Handling failed', err);

    if (err instanceof HmacError) {
      return buildResponse(403, (err as HmacError).message);
    }

    if (err instanceof ValidationError) {
      return buildResponse(400, (err as ValidationError).message);
    }

    return buildResponse(500, 'Internal server error');
  }

  return buildResponse(400, 'Unrecognized command');
};

export const eventBridgeHandler = async (
  event: EventBridgeEvent<'On-Demand Worker Request', any>,
) => {
  /**
   * The event is designed as safe to be logged. Any sensitive content
   * is encrypted when the integration is configured in production mode.
   */
  console.log(`Handling on-demand worker request: ${JSON.stringify(event)}`);

  const provisionerConfiguration = await getProvisionerConfiguration(
    parseEnvVariable('WORKER_PROVIDER_CONFIGURATION_SECRET'),
  );

  const clusterCfg = await getClusterConfiguration(
    provisionerConfiguration.clusterConfigParameterArn,
  );

  // TODO: implement decryption here.
  // For now we rely on the plaintext payload present in development mode.

  /**
   * Dispatch the workload to our ECS cluster.
   */
  const ecsProvisioner = getEcsProvisioner(clusterCfg);
  await ecsProvisioner.provisionWorker({
    /**
     * Pass information from the Control Room request.
     */
    linkToken: event.detail.payload.link_token,
    workspaceId: event.detail.metadata.workspace_id,
    workerId: event.detail.metadata.worker_id,

    /**
     * This controls which docker image gets started.
     * This request could easily be augmented with e.g. amount of
     * resources allocated for the task or other parameters passed
     * to the task definition.
     */
    imageUri: `${provisionerConfiguration.ecrRepositoryUrl}:${parseEnvVariable('ECR_IMAGE_TAG')}`,
  });
};
