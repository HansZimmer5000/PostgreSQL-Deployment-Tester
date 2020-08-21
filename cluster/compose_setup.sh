#!/bin/sh

# VARIABLES & CONSTANTS
################

print_setup_help(){
    echo "
This script sets up the environment (docker compose) to start a PostgreSQL Cluster.
--------------------
Flags:
-p  will start the postgres cluster at last.
-h  will print this help
"
}

postgres_is_not_running=false

while getopts 'hmsp' opts; do
    case ${opts} in 
        h)  print_setup_help 
            exit 0 ;;
        p)  postgres_is_not_running=true  ;;
    esac
done

echo "
    Starting Setup Script 
----------------------------------
with values:
postgres_is_not_running=$postgres_is_not_running
"

if $postgres_is_not_running; then
    # CleanUp
    echo "-- Cleaning Up Old Stuff"
    docker-compose -f stacks/stack95_compose.yml rm -fs
    docker-compose -f stacks/stack10_compose.yml rm -fs
    docker volume prune 
    docker rm $(docker ps -aq)

    # Start Stack 
    echo "-- Bringing Compose files up"
    docker-compose -f stacks/stack95_compose.yml up --scale db95=2 -d #--remove-orphans
    docker-compose -f stacks/stack10_compose.yml up --scale db10=0 -d #--remove-orphans
fi

echo "
Now execute compose_test_client.sh to continue"