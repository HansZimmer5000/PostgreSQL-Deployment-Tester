#!/bin/sh

docker rm -f $(docker ps -aq) 1> /dev/null
docker volume prune -f 1> /dev/null
sudo rm -rf postgres-upgrade-testing
sleep 1s

##

OLD='9.5'
NEW='10'
sleep_time=10
old_image="postgres:$OLD"
new_image="postgres:$NEW"

echo "-- Building Upgrade Image"
docker build image -f image/Dockerfile -t hanszimmer5000/postgres-upgrade:$OLD-to-$NEW 1> /dev/null

mkdir -p postgres-upgrade-testing
cd postgres-upgrade-testing
echo "-- Starting Old Image"
    #-v ../../compose_cluster/postgres/sub_setup.sh:/etc/sub_setup.sh \
    #-v ../../compose_cluster/postgres/table_setup.sql:/docker-entrypoint-initdb.d/init.sql \
    #-v ../../compose_cluster/postgres/sub_postgresql.conf:/usr/share/postgresql/postgresql.conf. sample \
	#-e PGDATA=/var/lib/postgresql/9.5/data\
docker run -dit \
    -e POSTGRES_PASSWORD=pass \
	--name postgres-upgrade-testing \
	-v "$PWD/$OLD/data":/var/lib/postgresql/data \
	"$old_image" 1> /dev/null

sleep $sleep_time
docker logs --tail 100 postgres-upgrade-testing

echo "-- Filling Old Image"
# let's get some testing data in there
docker exec -it \
	-u postgres \
	postgres-upgrade-testing \
	pgbench -i -s 10 1> /dev/null

#docker stop postgres-upgrade-testing 1> /dev/null
docker rm -f postgres-upgrade-testing 1> /dev/null

echo "-- Starting Upgrade"
set -e
docker run -it --rm \
	-v "$PWD/$OLD/data":/var/lib/postgresql/9.5/data \
	-v "$PWD/$NEW/data":/var/lib/postgresql/10/data \
	"hanszimmer5000/postgres-upgrade:$OLD-to-$NEW" bash

echo "-- Starting New Image"
docker run -dit \
	-e POSTGRES_PASSWORD=password \
	--name postgres-upgrade-testing \
	-v "$PWD/$NEW/data":/var/lib/postgresql/data \
	"$new_image" 1> /dev/null
sleep $sleep_time
docker logs --tail 10 postgres-upgrade-testing
