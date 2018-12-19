#!/usr/bin/env python

import os

with open('docker_bot_password','w') as f:
    f.write(os.environ['DOCKER_BOT_PASSWORD'])

