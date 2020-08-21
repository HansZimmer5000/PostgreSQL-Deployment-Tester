#!/bin/sh

# VARIABLES & CONSTANTS
################

source ./.env.sh

source ./helper_scripts/docker_helper.sh
source ./helper_scripts/postgres_helper.sh
source ./helper_scripts/id_ip_nodes.sh
source ./helper_scripts/ssh_scp.sh
source ./helper_scripts/vm_helper.sh
source ./setup_scripts/docker_setup.sh
source ./setup_scripts/keepalived_setup.sh
source ./setup_scripts/vm_setup.sh

print_setup_help(){
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
        h)  print_setup_help 
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
    echo "$all_nodes"
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
    prepare_keepalived
    prepare_swarm

    # Start Stack
    deploy_stack
else
    echo "-- Using existing stack V9.5 deployment"
fi

echo "
Now execute test_client.sh to continue"