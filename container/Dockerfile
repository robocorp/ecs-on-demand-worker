FROM debian:bookworm

# Set all variables that affect programs to follow same encoding
ENV LANG=C.UTF-8 LANGUAGE=C.UTF-8 LC_ALL=C.UTF-8

# libgtk-3-0 dependency added because Firefox installation from conda-forge
# depends on this library and it wasn't available in the base container

RUN apt-get update --fix-missing \
    && DEBIAN_FRONTEND=noninteractive apt-get upgrade -y \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y \
        wget \
        bzip2 \
        ca-certificates \
        curl \
        bash \
        chromium \
        chromium-driver \
        build-essential \
        libgtk-3-0 \
        git \
        fonts-indic \
        fonts-noto \
        fonts-noto-cjk \
        zip \
        libdbus-glib-1-2 \
        wkhtmltopdf \
        xvfb \
        libreoffice \
        unoconv \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    && echo "Installed Packages: " && dpkg -l

RUN useradd --no-log-init --system --create-home --shell /bin/bash worker

# Running as non sudo user 'worker'
USER worker
WORKDIR /home/worker

# Add Agent Core inside the image
RUN mkdir -p /home/worker/bin && \
    mkdir -p /home/worker/.robocorp && \
    mkdir -p /home/worker/bin/conda && \
    mkdir -p /home/worker/instance

COPY ./resources/rtconfig.yml instance/rtconfig.yml

RUN curl --silent --show-error --fail -o \
    /home/worker/bin/robocorp-worker \
    https://downloads.robocorp.com/workforce-agent-core/releases/latest/linux64/robocorp-workforce-agent-core
RUN chmod +x /home/worker/bin/robocorp-worker

# Initialize the Worker agent
RUN /home/worker/bin/robocorp-worker init --log-level TRACE --rcc-exec-path /home/worker/bin/rcc

# OPTIONAL: Prebuild common environment(s) into the container image
# This will increase the image size, but the environments prebuilt will be ready-to-go for robot executions.
#COPY ./prebuilt-env-2023-06-07.yaml prebuilt-envs/prebuilt-env-2023-06-07.yaml
#RUN /home/worker/bin/rcc ht vars prebuilt-envs/prebuilt-env-2023-06-07.yaml --space workforce --controller agent.core.container --timeline \
#    && rm -rf /home/worker/.robocorp/pipcache \
#    && rm -rf /home/worker/.robocorp/pkgs \
#    && rm -rf /home/worker/.robocorp/holotree/v*h

# Set the local scripts in place
COPY ./resources/start.sh start.sh

CMD [ "./start.sh" ]
