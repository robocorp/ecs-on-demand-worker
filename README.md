# ecs-on-demand-worker

Full example setup of [self-hosted on-demand workers](https://robocorp.com/docs/control-room/unattended/worker-setups/on-demand) on AWS ECS+EC2 using a custom Linux container to host the worker.

**Heads up!** We have recently [announced a terminology change](https://updates.robocorp.com/release/txLlE-terminology-assistant-and-process-updates) around this area of the product and some references to old terminology may be temporarily around until we complete the migration. For practical purposes, the following terms all mean the same and are rebranded as "Worker": runtime, (execution) environment, workforce agent, worker

## Introduction

This project consists of three main components in their respective subfolders.
 1. `terraform` that sets up the ECS cluster and associated resources on AWS.
 2. `container` (Docker) that hosts Robocorp Worker.
 3. `provisioner`, a serverless application that communicates with control room and manages the containers.

## Setup

If you want to keep up to date with updates to this repository easily, it is recommended to create a fork or otherwise setup tracking of the upstream changes.

### Prerequisites

 1. Robocorp Control Room organization with On-Demand Workers enabled. This feature is part of the Enterprise tier, or may otherwise be activated by Robocorp staff.
 1. Computer with [Terraform](https://www.terraform.io) v1.3+ and [Docker Desktop](https://docker.com) installed.
 The scripts in this repository will work as-is on MacOS and Linux, but can be easily adapted for Windows. Additional instructions for specific operating systems: [Amazon Linux 2](#amazon-linux-2)
 1. AWS Account with administrative privileges. We recommended reserving a dedicated AWS account for this
 workload within your AWS Organization according to AWS Best Practices.
 1. Basic knowledge of above mentioned tooling, AWS infrastructure and Robocorp technology stack.

### Terraform

The Terraform project deploys AWS resources on the target account, and *will start to incur costs
once applied*. The default configuration will cost < $100/month, with main cost drivers being
two small EC2 instances and two NAT gateways.

 1. Configure your Terraform state backend in `state-backend.tf`. The default configuration uses
 a S3 bucket and easiest option is to create a bucket on your account and change the bucket name in the configuration. Detailed instructions are out the scope of this example; please see [Terraform documentation](https://developer.hashicorp.com/terraform/language/state/remote) or utilize other readily available
 examples on the Internet.
 1. Apply the terraform project. It will set up a VPC, ECS+EC2 cluster, ECR repository and a Secrets Manager Secret + SSM parameter for passing configuration to the provisioner component. The default configuration
 deploys the resources on the `us-east-1` region.
    - `cd terrafrom`
    - `terraform init`
    - `terraform apply`

### Container image

The container image should contain everything needed for running the intended workloads. The default
Dockerfile contains an environment suitables for web automation.

 1. Build the docker container image
    - `cd container`
    - `docker build --platform linux/amd64 .`
 1. Upload the image to an image repository. To use the default repository set up by
Terraform above, run the following:
    - `./upload.sh <sha_from_build_output> v2.0`, where `v2.0` is the image tag name.
        - You can choose any tagging scheme, but the provisioner in this example uses image tag v2.0 by default.

### Provisioner

The provisioner is responsible for processing requests from Control Room and launching
worker containers when requested. It is implemented as a serverless application and deployed
as AWS Lambda functions behind AWS API Gateway.

 1. Change working directory to the `provisioner` folder
     - `cd provisioner`
 1. If you used something else than `v2.0` as the image tag name, configure the provisioner to use the tag given above.
     - edit `ECR_IMAGE_TAG` environment variable in `serverless.yaml`
 1. Deploy the provisioner application.
     - `npm ci`
     - `npm run deploy`
 1. Record the URL of the `worker-request` endpoint; it will be needed when configuring Control Room.

### Configure the provisioner in Control Room

Final step is to configure the setup in Control Room.

 1. Log in and navigate to Workers page of the workspace where the bots are located
 1. Click "Add" in the "Self-hosted On-demand Workers" list
     - `Name`: Enter a descriptive name
     - `URL`: copy-paste URL from the provisioner setup step above
     - `Secret`: secret has been generated and set up with the Terraform project setup. Open AWS secrets manager on the region where the project is deployed and retrieve value of the `secret` key in `rc-odw-1-config`.
1. The self-hosted worker can now be selected in Step configuration.


# Appendix

## Platform/distribution specific instructions

### Amazon Linux 2

NodeJS for setting up the provisioner must be installed separately on AWS Linux 2.
[AWS guide](https://docs.aws.amazon.com/sdk-for-javascript/v2/developer-guide/setting-up-node-on-ec2-instance.html) instructs using [Node Version Manager (nvm)](https://github.com/nvm-sh/nvm), which is a good choice.
 1. Follow the official NVM [installation instructions](https://github.com/nvm-sh/nvm#install--update-script)
 1. Close and reopen the terminal to apply the added configuration
 1. Make sure `nvm` is found
    - `nvm version`
    - If you get error `nvm not found`, try to activate it manually: `. ~/.nvm/nvm.sh`
 1. Install NodeJS v16 (AWS Linux 2 does not yet support v18):
    - `nvm install 16`
 1. Verify that npm is installed
    - `node --version`
 1. Proceed with provisioner setup as described above
