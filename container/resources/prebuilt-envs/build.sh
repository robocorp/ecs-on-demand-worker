#!/bin/bash

set -o errexit
shopt -s nullglob

for f in *.yaml;
do
  echo "Prebuilding environment specified in $f"
  /home/worker/bin/rcc ht vars $f --space workforce --controller agent.core.container --timeline
done

rm -rf /home/worker/.robocorp/pipcache
rm -rf /home/worker/.robocorp/pkgs
rm -rf /home/worker/.robocorp/holotree/v*h
