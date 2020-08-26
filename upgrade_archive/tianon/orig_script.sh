#!/bin/sh

docker rm -f $(docker ps -aq)
docker volume prune -f
sudo rm -rf postgres-upgrade-testing

mkdir -p postgres-upgrade-testing
cd postgres-upgrade-testing
OLD='9.5'
NEW='10'

docker pull "postgres:$OLD"
docker run -dit \
	--name postgres-upgrade-testing \
    -e POSTGRES_PASSWORD=pass \
	-v "$PWD/$OLD/data":/var/lib/postgresql/data \
	"postgres:$OLD"
sleep 5
docker logs --tail 100 postgres-upgrade-testing

# let's get some testing data in there
docker exec -it \
	-u postgres \
	postgres-upgrade-testing \
	pgbench -i -s 10

docker stop postgres-upgrade-testing
docker rm postgres-upgrade-testing

docker run --rm \
	-v "$PWD":/var/lib/postgresql \
	"tianon/postgres-upgrade:$OLD-to-$NEW" \
	--link

docker pull "postgres:$NEW"
docker run -dit \
	--name postgres-upgrade-testing \
	-v "$PWD/$NEW/data":/var/lib/postgresql/data \
	"postgres:$NEW"
sleep 5
docker logs --tail 100 postgres-upgrade-testing

# can now safely remove "$OLD"
sudo rm -rf "$OLD"