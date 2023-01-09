import {
  ECSClient,
  TaskDefinition,
  RegisterTaskDefinitionCommand,
  DescribeTaskDefinitionCommand,
  ClientException,
  RunTaskCommand,
} from '@aws-sdk/client-ecs';
import { buildTaskDefinition } from './ecs-container-profiles';
import { ClusterConfiguration } from './types';

const log = (message: string) => {
  console.log(message);
};

export interface ProvisionWorkerParams {
  linkToken: string;
  workspaceId: string;
  workerId: string;

  imageUri: string;
}

export class EcsProvisioner {
  private ecsClient: ECSClient;

  constructor(private cfg: ClusterConfiguration) {
    this.ecsClient = new ECSClient({});
  }

  async provisionWorker(params: ProvisionWorkerParams): Promise<void> {
    const baseTaskDefinition = buildTaskDefinition({
      executionRoleArn: this.cfg.ecsTaskExecutionRoleArn,
      taskRoleArn: this.cfg.robotRoleArn,
      imageUri: params.imageUri,
    });
    const taskDefinition = await this.setupTaskDefinition(baseTaskDefinition);

    log(`Starting container with task definition: ${JSON.stringify(taskDefinition)}`);

    const runTaskCommand = new RunTaskCommand({
      taskDefinition: taskDefinition.taskDefinitionArn,
      cluster: this.cfg.ecsClusterArn,
      overrides: {
        containerOverrides: [
          {
            name: taskDefinition.containerDefinitions![0].name,
            environment: [
              { name: 'RC_WORKER_NAME', value: `ws${params.workspaceId}/worker${params.workerId}` },
              { name: 'RC_WORKER_LINK_TOKEN', value: params.linkToken },
            ],
          },
        ],
      },
    });
    const runTaskResult = await this.ecsClient.send(runTaskCommand);
    console.log(`runTaskResult: ${JSON.stringify(runTaskResult)}`);
  }

  private async setupTaskDefinition(taskDefinition: TaskDefinition): Promise<TaskDefinition> {
    if (!taskDefinition?.family) {
      throw new Error('Task definition or family not set');
    }

    log(`Find existing task definition for family=${taskDefinition.family}`);
    const existing = await this.findTaskDefinitionByFamily(taskDefinition.family);

    if (existing) {
      log(`Task definition found.`);
      return existing;
    }
    log('Task definition does not exist. Creating.');
    const registerCommand = new RegisterTaskDefinitionCommand({
      containerDefinitions: taskDefinition.containerDefinitions,
      family: taskDefinition.family,
      executionRoleArn: taskDefinition.executionRoleArn,
      taskRoleArn: taskDefinition.taskRoleArn,
      networkMode: taskDefinition.networkMode,
      cpu: taskDefinition.cpu,
      memory: taskDefinition.memory,
    });
    const registered = await this.ecsClient.send(registerCommand);
    if (registered?.taskDefinition) {
      return registered.taskDefinition;
    }

    throw new Error('Unable to setup task definition.');
  }

  private async findTaskDefinitionByFamily(family: string): Promise<TaskDefinition | undefined> {
    try {
      const describeCommand = new DescribeTaskDefinitionCommand({
        taskDefinition: family,
      });
      const existing = await this.ecsClient.send(describeCommand);

      if (existing?.taskDefinition) {
        return existing.taskDefinition;
      }
    } catch (err) {
      if (err instanceof ClientException) {
        if (err.message === 'Unable to describe task definition.') {
          // This is the error we get if task definition simply does not exist
          log(`Existing task definition not found.`);
        }
      } else {
        // In other cases log more information; end result is still the same.
        throw new Error(`Unable to fetch existing task definition. Error: ${JSON.stringify(err)}`);
      }
    }

    return undefined;
  }
}
