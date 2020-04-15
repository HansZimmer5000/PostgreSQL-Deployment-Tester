#!/bin/sh

prepare_env_file() {
	echo OLD=$OLD > .env
	echo NEW=$NEW >> .env
}

pre_cleanup() {
	echo "--> Clean up old containers"
	docker rm -f $(docker ps -aq) 

	echo "--> Clean up volumes"
	docker volume rm data_9.5.18
    docker volume rm data_10.12

	rm -f .env
}

post_cleanup() {
	echo "--> Old data will be deleted"
	docker volume rm data_9.5.18
}

showcount() {
	echo "--> Show Counts"
	#docker exec -ti postgres-upgrade-testing psql -U postgres \postgres -c  "SELECT table_name FROM information_schema.tables WHERE table_name = 'pgbench_*'"
	log=$(docker exec -ti $1 psql -U postgres \postgres -c  "SELECT COUNT (*) FROM pgbench_accounts")
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
    docker stack deploy -c oldstack.yml old
	sleep 20s
}

startnewdb(){
	echo "--> Start new database"
	docker stack deploy -c newstack.yml new
	sleep 10s
}

removeolddb() {
	echo "--> Remove old database"
	docker stack rm old
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
		-v data_9.5.18:/var/lib/postgresql \
		pg_vol_upgrader:$OLD-$NEW \
		--link
}

filldb() {
	echo "--> Fill old database with sample data"
	docker exec -it \
		-u postgres \
		$old_container_id \
		pgbench -i -s 10
}

# Actual Script

echo "Beginn Upgrade from Postgres version 9.5.18 to 10.12"
OLD="9.5.18"
NEW="10.12"


pre_cleanup 

prepare_env_file

prepare_images

docker swarm init
docker volume create data_9.5.18
docker volume create data_10.12

startolddb
read -p "Insert Container ID: " old_container_id

filldb

showcount $old_container_id

removeolddb

upgradevol

startnewdb
read -p "Insert Container ID: " new_container_id

showcount $new_container_id

post_cleanup