#!/bin/sh

# This script needs to be manually run the once (and only once) before starting
# Listmonk for the first time. It uses the provided credentials to initialize
# its database.

set -o errexit
set -o xtrace

docker pull listmonk/listmonk

docker run --rm --name listmonk \
    -p 9000:9000 \
    -v /root/listmonk/config.toml:/listmonk/config.toml:ro \
    listmonk/listmonk ./listmonk --install
