#/usr/bin/env bash
{ python3 <<EOF
import os
print(os.environ['DOCKER_BOT_PASSWORD'])                                                                              
EOF 
} | docker login --username="${DOCKER_BOT_USER}" --password-stdin
unset DOCKER_BOT_PASSWORD
unset DOCKER_BOT_USER

