#!/bin/sh

source ./.env.sh
source helper_scripts/docker.sh
source helper_scripts/id_ip_nodes.sh
source helper_scripts/postgres.sh

upgrade_instance(){
    #TODO
    :
}

rollback_all_subscriber(){
    #TODO implement rollback
    :
}

start_upgrade_single(){
    read -p "Please enter name of single postgres to upgrade: " sub_name
    #upgrade_instance "$sub_name"

    kill_pg_by_name $sub_name smart
    update_id_ip_nodes
    start_new_subscriber 10
    #TODO wait for boot and then promote?
}

start_upgrade(){
    update_id_ip_nodes
    print_id_ip_nodes
    total_postgres_count=$(get_tuples_count)

    if [ "$total_postgres_count" -eq 1 ]; then
        start_upgrade_single
    else
        # TODO implement Multi Postgres 
        :
    fi
}

start_upgrade
