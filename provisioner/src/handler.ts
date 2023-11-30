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
import { decryptData } from './encryption';

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

  let linkToken;
  try {
    const key = Buffer.from(provisionerConfiguration.secret, 'utf8');
    const ciphertext = Buffer.from(event.detail.encrypted_payload, 'base64');
    const decryptedData = await decryptData(ciphertext, key);
    const decryptedPayload = JSON.parse(decryptedData.toString('utf8'));
    linkToken = decryptedPayload.link_token;
    if (linkToken) {
      console.log('Successfully decrypted link token from encrypted payload.');
    }
  } catch (e) {
    console.log('Decryption failed', e);
  }

  if (!linkToken) {
    if (event.detail.payload?.link_token) {
      console.log(
        'Failed to extract link token from decrypted payload, but plaintext link token exists in the message indicating development mode; proceeding with the plaintext token.',
      );
      linkToken = event.detail.payload?.link_token;
    } else {
      throw new Error('Cannot extract link token');
    }
  }
  /**
   * Dispatch the workload to our ECS cluster.
   */
  const ecsProvisioner = getEcsProvisioner(clusterCfg);
  await ecsProvisioner.provisionWorker({
    /**
     * Pass information from the Control Room request.
     */
    linkToken,
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
