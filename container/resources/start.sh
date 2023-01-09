#!/bin/bash

set -o errexit

if [ -z "${RC_WORKER_LINK_TOKEN}" ]; then
  echo "usage $0 <link_token> [name]"
  exit 1
fi

if [ -z "${RC_WORKER_NAME}" ]; then
  RC_WORKER_NAME=container-on-`hostname -s`
fi

echo "Linking worker with name=${RC_WORKER_NAME}"

/home/worker/bin/robocorp-worker link ${RC_WORKER_LINK_TOKEN} --name ${RC_WORKER_NAME} --instance-path /home/worker/instance --log-level TRACE
echo "Linking succeeded. Starting the agent..."

exec /home/worker/bin/robocorp-worker start --instance-path /home/worker/instance --log-level TRACE --run-once
