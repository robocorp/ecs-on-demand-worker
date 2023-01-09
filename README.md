# ecs-on-demand-worker

Full example setup of [self-hosted on-demand workers](https://robocorp.com/docs/control-room/unattended/worker-setups/on-demand) on AWS ECS+EC2 using a custom Linux container to host the worker.

**Heads up!** We have recently [announced a terminology change](https://updates.robocorp.com/release/txLlE-terminology-assistant-and-process-updates) around this area of the product and some references to old terminology may be temporarily around until we complete the migration. For practical purposes, the following terms all mean the same and are rebranded as "Worker": runtime, (execution) environment, workforce agent, worker

## Introduction

This project consists of three main components in their respective subfolders.
 1. `terraform` that sets up the ECS cluster and associated resources.
 2. `container` (Docker) that hosts Robocorp Worker.
 3. `provisioner`, a serverless application that communicates with control room and manages the containers.

## Prerequisites
 - AWS account
 - Robocorp Control Room organization with On-Demand Workers enabled
 - Familiar with the stack (or willing to learn): AWS ECS, EC2, Lambda, Typescript, Serverless Framework. The basic setup does not require extensive knowledge, but this example does not aim to teach you all the basics.

## Setup

If you want to keep up to date with updates to this repository easily, it is recommended to create a fork or otherwise setup tracking of the upstream changes.

Steps to bootstrap:
 1. Apply the terraform project. It will set up a VPC, ECS+EC2 cluster, ECR repository and a Secrets Manager Secret + SSM parameter for passing configuration to the provisioner.
    - You need to configure your own state backend in `state-backend.tf`. Instructions are out the scope of this example; please see [Terraform documentation](https://developer.hashicorp.com/terraform/language/state/remote).
    - The example uses HashiCorp cloud.
 2. Build the docker container and upload taggd image to ECR.
    - `cd container`
    - `docker build .`
    - `./upload.sh <sha_from_build_output> <tag_name>`
 3. Update the provisioner to use the tag given above
     - edit `ECR_IMAGE_TAG` in serverless.yaml
 4. Deploy the provisioner application.
     - `cd provisioner`
     - `npm ci`
     - `sls deploy`
