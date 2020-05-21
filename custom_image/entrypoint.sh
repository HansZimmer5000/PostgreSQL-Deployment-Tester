#!/bin/sh

docker-entrypoint.sh postgres &
tail -f entrypoint.sh