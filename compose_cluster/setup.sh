#!/bin/sh

build_images(){
    docker build ../custom_image -f ../custom_image/9.5.18.dockerfile -t mypglog:9.5
    docker build ../custom_image -f ../custom_image/10.13.dockerfile -t mypglog:10
}

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
    echo "-- Building Images"
    build_images 1> /dev/null

    echo "-- Cleaning Up Old Stuff"
    docker-compose -f stacks/stack95_compose.yml rm -fs 1> /dev/null
    docker-compose -f stacks/stack10_compose.yml rm -fs 1> /dev/null
    docker volume prune 
    docker rm $(docker ps -aq)

    echo "-- Bringing Compose files up"
    docker-compose -f stacks/stack95_compose.yml up --scale db95=1 -d 1> /dev/null 
    docker-compose -f stacks/stack10_compose.yml up --scale db10=0 -d 1> /dev/null
fi

echo "
Now execute test_client.sh to continue"