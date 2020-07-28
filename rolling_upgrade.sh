import_code(){
    source ./.env

    source ./setup_scripts/ssh_scp.sh
    source ./setup_scripts/keepalived.sh
    source ./setup_scripts/docker.sh
    source ./setup_scripts/vm.sh

    source "./test_scripts/id_ip_nodes.sh"
    source "./test_scripts/test_scenarios.sh"
    source "./test_scripts/docker_cmds.sh"
    source "./test_scripts/pg_cmds.sh"
    source ./test_scripts/test_client_lib.sh
}

start_upgrade_phase_one(){
    read -p "Please enter name of first postgres to upgrade: " sub_name
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
    total_number_of_upgraded_postgres_instances=$(get_tuples_count)
    upgrade_provider $total_number_of_upgraded_postgres_instances
}

start_upgrade(){
    update_id_ip_nodes
    print_id_ip_nodes

    start_upgrade_phase_one
    print_id_ip_nodes
    read -p "First Phase Done, Continue?"

    start_upgrade_phase_two
    print_id_ip_nodes
    read -p "Second Phase Done, Continue?"

    start_upgrade_phase_three
    print_id_ip_nodes
    echo "Third Phase Done"
}

# Must move to "cluster" folder since code contains relative paths!
cd cluster

import_code
start_upgrade

# Switch back to original folder.
cd ..