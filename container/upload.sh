#!/bin/sh

#
# Helper script that uploads a docker image to ECS repository set up by the terraform project.
#
# Build image first using 'docker build .'
# After uploading image, update the provisioner to use the new image by configuring
# the tag in serverless.yaml environment variable ECR_IMAGE_TAG.
#

set -o errexit

if [ $# -ne 2 ]
then
  echo "usage: $0 <image sha> <tag>"
  exit 1
fi

ONDEMAND_WORKER_ID=rc-odw-1
REGION=us-east-1

IMAGE_SHA=$1
TAG=$2

echo Fetch repository details...
REPOSITORY_DETAILS=`aws ecr describe-repositories --region ${REGION} --repository-names ${ONDEMAND_WORKER_ID}-worker-images`

REPOSITORY_URI=`echo ${REPOSITORY_DETAILS} | jq -r ".repositories[0].repositoryUri"`

echo Repository found. URI: ${REPOSITORY_URI}

echo Tagging image...
docker tag ${IMAGE_SHA} ${REPOSITORY_URI}:${TAG}

echo Logging in...
aws ecr get-login-password --region ${REGION} | docker login --username AWS --password-stdin ${REPOSITORY_URI}

echo Pushing image...
docker push ${REPOSITORY_URI}:$TAG
