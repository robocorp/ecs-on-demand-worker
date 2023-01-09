Content-Type: multipart/mixed; boundary="==BOUNDARY=="
MIME-Version: 1.0

--==BOUNDARY==
MIME-Version: 1.0
Content-Type: text/cloud-boothook; charset="us-ascii"
#!/bin/bash

# Install security updates
yum update-minimal --security -y

# Set iptables configuration for blocking the instance metadata from docker containers,
# according to the guide here: https://aws.amazon.com/premiumsupport/knowledge-center/ecs-container-ec2-metadata/

yum install iptables-services -y

cat <<'EOF' > /etc/sysconfig/iptables
*filter
:DOCKER-USER - [0:0]
-A DOCKER-USER -d 169.254.169.254/32 -j DROP
COMMIT
EOF

systemctl enable iptables
systemctl start iptables

--==BOUNDARY==
MIME-Version: 1.0
Content-Type: text/cloud-boothook; charset="us-ascii"
#!/bin/bash

# ECS configuration
cloud-init-per instance ecs_options cat <<'EOF' > /etc/ecs/ecs.config
ECS_CLUSTER=${cluster_name}
ECS_ENGINE_TASK_CLEANUP_WAIT_DURATION=30m
ECS_RESERVED_MEMORY=256
ECS_AVAILABLE_LOGGING_DRIVERS=["json-file","syslog","awslogs","none"]
ECS_DISABLE_PRIVILEGED=true
ECS_AWSVPC_BLOCK_IMDS=true
ECS_IMAGE_PULL_BEHAVIOR=prefer-cached
EOF

--==BOUNDARY==--
