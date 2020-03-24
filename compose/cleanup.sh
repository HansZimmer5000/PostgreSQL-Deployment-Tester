#!/bin/sh

docker rm -f $(docker ps -aq)
docker system prune -f --volumes
rm -r *data || true
