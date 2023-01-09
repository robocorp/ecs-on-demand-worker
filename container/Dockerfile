# Stick with Ubuntu 18.04 because:
#  - Starting with 20.04 chromium-browser is available via a snap, which
#    does not work with containers
#  - Workforce agent itself has some known compatibility problems with 22.04
FROM ubuntu:18.04

ENV LANG=C.UTF-8 LANGUAGE=C.UTF-8 LC_ALL=C.UTF-8 DEBIAN_FRONTEND=noninteractive

# Install updates and dependencies.
# Can be amended to include anything your bots need.
RUN apt-get update && apt-get upgrade && \
  # wget needed during container build
  apt-get -y install wget && \
  # These dependencies are part of the standard Robocorp container.
  # They are not mandatory, but if you want to have a drop-in replacement
  # for the Robocorp-hosted cloud containers, this makes it easier.
  apt-get install -y wget bzip2 ca-certificates curl bash chromium-browser chromium-chromedriver build-essential libgtk-3-0 && \
  apt-get install -y fonts-indic fonts-noto fonts-noto-cjk && \
  apt-get install -y zip libdbus-glib-1-2 && \
  apt-get install -y git && \
  # Clean up debs to reduce the image size
  apt-get clean && \
  rm -rf /var/lib/apt/lists/*

# Setup a dedicatd user for worker
RUN useradd -ms /bin/bash worker

USER worker
WORKDIR /home/worker

# Download and initialize worker application.
#  - download site still has the old name "workforce agent", but we'll
#    opt in to the new naming locally
RUN mkdir bin && \
  wget https://downloads.robocorp.com/workforce-agent-core/releases/latest/linux64/robocorp-workforce-agent-core -O bin/robocorp-worker && \
  chmod a+x ./bin/robocorp-worker && \
  ./bin/robocorp-worker init --instance-path /home/worker/instance

# Set up a precrafted worker configuration file. The default is most likely fine,
# and seldom needs any tuning.
COPY resources/rtconfig.yml /home/worker/instance/

# Script that deals with starting the worker.
COPY resources/start.sh start.sh

# To optimize start times of robots, construct python environments for common
# python environments here. In our example we're using https://github.com/robocorp/example-google-image-search,
# and thus fetching the latest conda.yaml.
RUN wget https://raw.githubusercontent.com/robocorp/example-google-image-search/main/conda.yaml -O /tmp/prebuilt-conda.yaml && \
    ./bin/rcc holotree --space workforce --controller agent.core.container --liveonly variables /tmp/prebuilt-conda.yaml && \
    rm /tmp/prebuilt-conda.yaml

ENTRYPOINT [ "./start.sh" ]
