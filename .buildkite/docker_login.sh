#/usr/bin/env bash
docker login --username="${DOCKER_BOT_USER}" --password-stdin <(python3 <<EOF
import os
print(os.environ['DOCKER_BOT_PASSWORD'])                                                                              
EOF
)
unset DOCKER_BOT_PASSWORD
unset DOCKER_BOT_USER

