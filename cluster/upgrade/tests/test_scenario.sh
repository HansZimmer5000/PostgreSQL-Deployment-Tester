#!/bin/sh

prepare_env_file() {
	echo OLD=$OLD > .env
	echo NEW=$NEW >> .env
	echo VOLUME_DIR=$VOLUME_DIR >> .env
}

pre_cleanup() {
	echo "--> Clean up old containers"
	docker rm -f $(docker ps -aq) 

	echo "--> Clean up volumes"
	rm -rf $VOLUME_DIR
	mkdir -p $VOLUME_DIR

	rm -f .env
}

post_cleanup() {
	echo "--> Old data will be deleted"
	rm -rf "./$VOLUME_DIR/$OLD"
}

showcount() {
	echo "--> Show Counts"
	#docker exec -ti postgres-upgrade-testing psql -U postgres \postgres -c  "SELECT table_name FROM information_schema.tables WHERE table_name = 'pgbench_*'"
	log=$(docker exec -ti postgres-upgrade-testing psql -U postgres \postgres -c  "SELECT COUNT (*) FROM pgbench_accounts")
	if [[ $log == *"1000000"* ]]; then
  		echo "Content seems correct!"
	else
		echo "Content seems not to work: $log"
	fi
}

prepare_images() {
	docker pull postgres:$OLD
	docker pull postgres:$NEW
}

startolddb() {
	echo "--> Start up old database"
	docker-compose -f oldstack.yml up -d --quiet-pull --no-color
	sleep 10s
}

startnewdb(){
	echo "--> Start new database"
	docker-compose -f newstack.yml up -d --quiet-pull --no-color
	sleep 10s
}

removeolddb() {
	echo "--> Remove old database"
	docker-compose -f oldstack.yml down
	sleep 10s
}

upgradevol() {
	echo "--> Upgrade Database vom $OLD to $NEW"

	# Build the upgrade image
	cd ../gen_docker
	./build.sh $OLD $NEW
	cd ../tests

	docker run \
		--rm \
		-v "$PWD/$VOLUME_DIR":/var/lib/postgresql \
		pg_vol_upgrader:$OLD-$NEW \
		--link
}

filldb() {
	echo "--> Fill old database with sample data"
	docker exec -it \
		-u postgres \
		postgres-upgrade-testing \
		pgbench -i -s 10
}

# Actual Script

OLD=$1
NEW=$2
VOLUME_DIR=vol

if [ -z "$OLD" ]; then
	echo "No OLD (Param 1) Version was given! Using Default 9.5"
	OLD=9.5
fi

if [ -z "$NEW" ]; then
	echo "No NEW (Param 2) Version was given! Using Default 10"
	NEW=10
fi

echo "Beginn Upgrade from Postgres version $OLD to $NEW"

pre_cleanup 

prepare_env_file

prepare_images

startolddb

filldb

showcount

removeolddb

upgradevol

startnewdb

showcount

post_cleanup