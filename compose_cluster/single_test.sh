#!/bin/sh

source helper_scripts/postgres.sh
source helper_scripts/id_ip_nodes.sh
source helper_scripts/docker.sh

echo "-- Start Old Postgres"
# Start Old Postgres
./setup.sh -p 1> /dev/null
sleep 20s
update_id_ip_nodes
print_id_ip_nodes

echo "-- Promote Old Postgres"
# Promote Old Postgres
promote_sub stacks_db95_1 1> /dev/null
update_id_ip_nodes
print_id_ip_nodes

echo "-- Fill Old Postgres"
docker exec -it \
	-u postgres \
	stacks_db95_1 \
	pgbench -i -s 10 

echo "-- Crash Old Postgres"
remove_old_provider stacks_db95_1
kill_pg_by_name stacks_db95_1 smart
update_id_ip_nodes
print_id_ip_nodes

echo "-- Updating Volume"
docker run --rm \
    -v stacks_pgdata95:/var/lib/postgresql/9.5/data \
    -v stacks_pgdata10:/var/lib/postgresql/10/data \
	"tianon/postgres-upgrade:9.5-to-10" \
	--link

echo "-- Start New Postgres"
docker run -dit \
	--name postgres-upgrade-testing \
	-v stacks_pgdata10:/var/lib/postgresql/data \
	"postgres:10" 

docker exec postgres-upgrade-testing ls /var/lib/postgresql/data
docker exec postgres-upgrade-testing cat /var/lib/postgresql/data/PG_VERSION

exit 0

echo "-- Start New Postgres"
start_new_subscriber 10
sleep 20s
update_id_ip_nodes
print_id_ip_nodes
docker logs stacks_db10_1

