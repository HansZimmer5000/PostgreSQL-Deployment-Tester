import_code(){
    source ./.env.sh
    source ./test_client.sh

    source ./helper_scripts/ssh_scp.sh
    source ./helper_scripts/keepalived_helper.sh
    source ./helper_scripts/docker_helper.sh
    source ./helper_scripts/vm.sh

    source ./helper_scripts/id_ip_nodes.sh
    source ./helper_scripts/test_scenarios.sh
    source ./helper_scripts/postgres_helper.sh
}

rollback_all_subscriber(){
    #TODO implement more sophisticated rollback that checks if every step was successfull or not.
    reset_labels $1 0
    scale_service_with_timeout pg10_db 0
    scale_service_with_timeout pg95_db $1
}

start_upgrade_phase_one(){
    read -p "Please enter name of first postgres subscriber to upgrade: " sub_name
    upgrade_subscriber $sub_name 1
}

start_upgrade_phase_two(){
    next_total_number_of_upgraded_postgres_instances=2
    for subscriber_tuple in $(get_all_subscriber); do
        version=$(get_version $subscriber_tuple)
        if [[ "$version" == "9.5"* ]]; then
            name=$(get_name $subscriber_tuple)
            upgrade_subscriber $name $next_total_number_of_upgraded_postgres_instances
        fi
        next_total_number_of_upgraded_postgres_instances=$((next_total_number_of_upgraded_postgres_instances+1))
    done
}

start_upgrade_phase_three(){
    update_id_ip_nodes
    upgrade_provider $1
}

start_upgrade(){
    # TODO always validate user input
    update_id_ip_nodes
    print_id_ip_nodes
    total_postgres_count=$(get_tuples_count)

    start_upgrade_phase_one
    print_id_ip_nodes
    echo "First Phase Done, Continue ('y') or Rollback ('r')?"
    read -p ">" answer

    if [ "$answer" != "r" ]; then
        start_upgrade_phase_two
        print_id_ip_nodes
        echo "Second Phase Done, Continue ('y') or Rollback ('r')?"
        read -p ">" answer

        if [ "$answer" != "r" ]; then
            start_upgrade_phase_three $total_postgres_count
            print_id_ip_nodes
            echo "Third Phase Done"
        else
            rollback_all_subscriber $total_postgres_count
        fi
    else
        rollback_all_subscriber $total_postgres_count
    fi
}

import_code
start_upgrade
