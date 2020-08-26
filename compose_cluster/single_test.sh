#!/bin/sh

source ./.env.sh
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
#promote_sub stacks_db95_1 1> /dev/null
#update_id_ip_nodes
#print_id_ip_nodes

echo "-- Fill Old Postgres"
docker exec -it \
	-u postgres \
	stacks_db95_1 \
	pgbench -i -s 2 

echo "-- Crash Old Postgres"
#remove_old_provider stacks_db95_1
kill_pg_by_name stacks_db95_1 smart
update_id_ip_nodes
print_id_ip_nodes

#echo "-- Updating Volume"
#docker run -it --rm \
#    -v stacks_pgdata95:/var/lib/postgresql/9.5/data \
#    -v stacks_pgdata10:/var/lib/postgresql/10/data \
#	-v $(pwd)/postgres/sub_postgresql.conf:/usr/share/postgresql/postgresql.conf.sample \
#	-v $(pwd)/postgres/sub_postgresql.conf:/usr/share/postgresql/10/postgresql.conf.sample \
#	"hanszimmer5000/postgres-upgrade:9.5-to-10" bash

# Notes for Update Success
# - Needs right postgresql.config (shared librarier)
# - Need right volume mount points
# - maybe execute pg_upgrade via root
#	- but then check locale
#	- but then check encoding (maybe already done with locale)
# - set all variables and PGDATA correct
# - new data must be initdb before
# - install needed librariers via apt-get (pglogical 9.5 / postgres 9.5)

echo "-- Start New Postgres"
start_new_subscriber 10
sleep 20s
update_id_ip_nodes
print_id_ip_nodes
docker logs stacks_db10_1

