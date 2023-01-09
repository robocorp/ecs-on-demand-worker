import { TaskDefinition } from '@aws-sdk/client-ecs';
import { parseEnvVariable } from './utils';
import { createHash } from 'crypto';

export type TaskDefinitionParams = {
  imageUri: string;
  executionRoleArn: string;
  taskRoleArn: string;
};

export function buildTaskDefinition(taskDefinitionParams: TaskDefinitionParams): TaskDefinition {
  const taskDefinition: TaskDefinition = {
    containerDefinitions: [
      {
        name: 'default',
        memoryReservation: 256,
        cpu: 256,
        image: taskDefinitionParams.imageUri,
        logConfiguration: {
          logDriver: 'awslogs',
          options: {
            'awslogs-create-group': 'true',
            'awslogs-region': parseEnvVariable('AWS_REGION'),
            'awslogs-group': '/robocorp-ondemand-worker/',
            'awslogs-stream-prefix': 'step-run',
          },
        },
      },
    ],
    family: 'PLACEHOLDER',
    networkMode: 'bridge',
    executionRoleArn: taskDefinitionParams.executionRoleArn,
    taskRoleArn: taskDefinitionParams.taskRoleArn,
  };

  taskDefinition.family = `${parseEnvVariable('ODW_ID')}-${hashBaseTaskDefinition(taskDefinition)}`;

  return taskDefinition;
}

function hashBaseTaskDefinition(taskDefinition: TaskDefinition): string {
  const json = JSON.stringify(taskDefinition);
  const sha256 = createHash('sha256').update(json).digest('hex');
  return sha256;
}
