#!/bin/sh

# VARIABLES & CONSTANTS
################

source ./.env

source ./helper_scripts/ssh_scp.sh
source ./helper_scripts/keepalived.sh
source ./helper_scripts/docker.sh
source ./helper_scripts/vm.sh

print_help(){
    echo "
This script sets up the environment (machines and docker swarm) to start a PostgreSQL Cluster for certain experiments.
--------------------
Flags:
-m  will start the VMs first (Only works on MacOS and Linux with VirtualBoxManager so far).
-s  will initialize the swarm cluster ontop of the running VMS.
-p  will start the postgres cluster <als letztes>.
-h  will print this help
"
}

machines_are_not_running=false
swarm_is_not_initialized=false
postgres_is_not_running=false

# 'hmsp:' would mean p also delivers a value (p=4), get it with $OPTARG
while getopts 'hmsp' opts; do
    case ${opts} in 
        h)  print_help 
            exit 0 ;;
        m)  machines_are_not_running=true ;;
        s)  swarm_is_not_initialized=true ;;
        p)  postgres_is_not_running=true  ;;
    esac
done

echo "
    Starting Setup Script 
----------------------------------
with values:
machines_are_not_running=$machines_are_not_running
swarm_is_not_initialized=$swarm_is_not_initialized
postgres_is_not_running=$postgres_is_not_running
"

if $machines_are_not_running; then
    echo "-- Starting VMs"
    start_machines
    sleep 10s
else
    echo "-- Using already started VMs"
fi

if $swarm_is_not_initialized; then
    echo "-- Starting Keepalived"
    start_keepalived
    echo "-- Starting Docker"
    echo "$ALL_NODES"
    start_swarm
    echo "-- Check if both nodes are in swarm"
    check_swarm
else
    echo "-- Skipping Docker Swarm and Keepalived setup"
fi

if $postgres_is_not_running; then
    # CleanUp
    echo "-- Cleaning Up Old Stuff"
    clean_docker

    # Prepare 
    echo "-- Preparing Machines and Swarm"
    prepare_machines
    prepare_swarm

    # Start Stack
    deploy_stack
else
    echo "-- Using existing stack V9.5 deployment"
fi

source "./helper_scripts/test_client_lib.sh"
running_loop

