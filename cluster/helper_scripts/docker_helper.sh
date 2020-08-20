#!/bin/sh

# Depends on (will be sourced by using script):
# - ssh_scp.sh

# extract_token extracts and returns the Docker Swarm Join Token from a given text.
# $1 = The text that the Docker Swarm Manager outputs when a new Docker Swarm is created which includes the Join Token
# Context: SETUP
extract_token_failure_text="NOT FOUND"
extract_token() {
    result="$extract_token_failure_text"

    token_raw=($(echo $1 | grep -o "SWMTKN.*"))
    if [ "${#token_raw[@]}" -gt 0 ]; then
        result=${token_raw[0]}
    fi

    echo $result
}

# set_label sets a given label on a given Docker Swarm Node
# $1 = Docker Swarm Nodes hostname
# $2 = Label
# $3 = Label Value
# Context: SETUP, TEST, UPGRADE
set_label(){
    # Do not delete the label before setting it, otherwise swarm most certainly will shutdown depended containers.
    $SSH_CMD root@$manager_node docker node update --label-add $2=$3 $1
}

# set_version_label_of_index sets the 'pg_ver' label of a given Docker Swarm Nodes index to the given value.
# $1 = Node Index
# $2 = New version label value
# Context: SETUP, TEST, UPGRADE
set_version_label_of_index() {
    hostname=$(get_hostname $1)
    if [ -z "$hostname" ]; then
        echo "Could not find the hostname for index $1"
        exit 1
    else
        set_label $hostname "pg_ver" "$2" 1> /dev/null
    fi
}

# set_version_label_of_IP_to_10 sets the 'pg_ver' label of a given Docker Swarm Nodes IP to 10.
# $1 = Host IP
# Context: SETUP, TEST, UPGRADE
set_version_label_of_IP_to_10(){
    index=$(get_index_of_dsn_node $1)
    if ! [ -z "$index" ] && [ $index -ge 0 ]; then
        set_version_label_of_index $index 10
    fi
}

# get_version_label returns the 'pg_ver' label value of a given Docker Swarm Nodes index.
# $1 = Node Index
# Context: SETUP, TEST, UPGRADE
get_version_label(){
    hostname=$(get_hostname $1)
    $SSH_CMD root@$manager_node "docker node inspect -f '{{ .Spec.Labels.pg_ver }}' $hostname"
}

# prepare_swarm prepares the Docker Swarm Nodes to properly deploy the postgres cluster
# Context: SETUP
prepare_swarm() {
    set_docker_files
    build_images 1>/dev/null
    set_v95_and_v10_labels $(get_node_count) 0
}

# set_docker_files copies the neccessary docker files onto the Docker Swarm Nodes.
# Context: SETUP
set_docker_files(){
    set_stacks
    set_configs
    set_scripts
}

# set_stacks copies the neccessary stack files onto the Docker Swarm Nodes.
# Context: SETUP
set_stacks() {
    scp_cmd_for_each_node ./stacks/stack95.yml /root/
    scp_cmd_for_each_node ./stacks/stack10.yml /root/
    scp_cmd_for_each_node ./stacks/portainer-agent-stack.yml /root/
}

# gather_running_containers returns the ids and names of all container running on a given host
# $1 = Hostname
# Context: SETUP, TEST, UPGRADE
gather_running_containers() {
    $SSH_CMD $1 'docker ps --format "table {{.ID}}\t{{.Names}}"'
}

# reset_config resets a given Docker Swarm config and its file according to given local and remote locations.
# $1 = Configname
# $2 = Local location of the file that will be the config
# $3 = Remote location of the file that will be the config
# Context: SETUP, TEST
reset_config() {
    $SSH_CMD root@$manager_node "docker config rm $1" 2>/dev/null
    $SCP_CMD $2 root@$manager_node:$3
    $SSH_CMD root@$manager_node "docker config create $1 $3"
}

# build_images copies the needed files and builds the images on the Docker Swarm nodes.
# Context: SETUP
build_images() {
    scp_cmd_for_each_node "../custom_image/9.5.18.dockerfile" /etc/
    scp_cmd_for_each_node "../custom_image/10.13.dockerfile" /etc/
    scp_cmd_for_each_node "../custom_image/docker-entrypoint.sh" /etc/
    ssh_cmd_for_each_node "chmod +x /etc/docker-entrypoint.sh"

    ssh_cmd_for_each_node "docker build /etc/ -f /etc/9.5.18.dockerfile -t mypglog:9.5-raw"
    ssh_cmd_for_each_node "docker build /etc/ -f /etc/10.13.dockerfile -t mypglog:10-raw"
}

# set_configs resets two Docker Swarm configs and their files.
# Context: SETUP
set_configs() {
    reset_config "tables" "./postgres/table_setup.sql" "/etc/table_setup.sql"
    reset_config "sub_config" "./postgres/sub_postgresql.conf" "/etc/sub_postgresql.conf"
}

# clean_docker will delete stacks, running containers and prune the volumes with force on the Docker Swarm nodes.
# Context: SETUP
clean_docker() {
    $SSH_CMD root@$manager_node "docker stack rm pg95"
    $SSH_CMD root@$manager_node "docker stack rm pg10"
    sleep 10s #Wait till everything is deleted

    ssh_cmd_for_each_node "docker rm $(docker ps -aq) -f"
    ssh_cmd_for_each_node "docker volume prune -f"
}

# deploy_stack will deploy the stacks.
# Context: SETUP
deploy_stack() {
    $SSH_CMD root@$manager_node "docker stack deploy -c stack95.yml pg95"
    $SSH_CMD root@$manager_node "docker stack deploy -c stack10.yml pg10"
    $SSH_CMD root@$manager_node "docker stack deploy -c portainer-agent-stack.yml portainer"
    sleep 15s #Wait till everything has started

    echo "-- Connect to Portainer at: http://$manager_node:9000/"
}

# start_swarm will start docker and create the Docker Swarm
# Context: SETUP
start_swarm() {
    ssh_cmd_for_each_node "systemctl start docker"
    ssh_cmd_for_each_node "docker swarm leave -f"

    full_init_msg=$($SSH_CMD root@$manager_node "docker swarm init --advertise-addr $manager_node")
    TOKEN=$(extract_token "$full_init_msg")

    for current_node in $other_nodes; do
        $SSH_CMD root@$current_node "docker swarm join --token $TOKEN $manager_node:2377"
    done
}

# check_swarm will check if any node delcared in the .env.sh file is existent in the Docker Swarm.
# Context: SETUP
check_swarm() {
    nodes=$($SSH_CMD root@$manager_node "docker node ls")
    if [ -z "$nodes" ]; then
        echo "Is Manager Node ready? Aborting"
        exit 1
    else
        for current_hostname in $all_hostnames; do
            if [[ "$nodes" != *"$current_hostname"* ]]; then
                echo "Is $current_hostname ready? Aborting"
                exit 1
            fi
        done
    fi

    echo "Both Nodes are up!"
}

# scale_service_with_timeout will set the scale of a given service to a given number with a timeout of 25s and a check if scaling was successfull. This function will only return a message if the scaling was unsuccessfull.
# $1 = Servicename
# $2 = new scale number
# Context: SETUP, TEST, UPGRADE
scale_service_with_timeout(){
    if  [ -z "$1" ] || [ -z "$2" ]; then
        echo "Missing Servicename or new replication count!"
    else
        timeout 25s $SSH_CMD root@$manager_node "docker service scale $1=$2"
        exit_code="$?"
        if [ "$exit_code" -gt 0 ]; then
            echo "Could not scale the service! Exit Code was: $exit_code"
        fi
    fi
}

# stop_pg_container stop a given Postgres container by its name. 
# $1 = Postgres instance name according to ID_IP_NODES.sh
# $2 = "smart". Will stop the container via a smart shutdown, if omitted the container will be stopped via 'docker rm'
# Context: TEST, UPGRADE
stop_pg_container(){
    tuple=$(get_tuple_from_name $1)
    node=$(get_node $tuple)
    id=$(get_id $tuple)

    if [ $2 == "smart" ]; then
        $SSH_CMD root@$CURRENT_NODE "docker exec $CURRENT_ID pg_ctl stop -m smart"
    else
        $SSH_CMD root@$node "docker rm -f $id"
    fi
}

# kill_provider stops the Postgres Provider. BEWARE this only works under the assumption that there is at most one provider in the system! Otherwise it will kill all providers.
# $1 = "-c" If given will only kill the provider. If omitted this function will also scale the service down by one to avoid a restart.
# $1 or $2 = "smart". Will stop postgres via a smart shutdown
# Context: TEST, UPGRADE
kill_provider(){
    for tuple in $(get_all_tuples); do
        current_role=$(get_role "$tuple")
        if [[ $current_role == "prov" ]]; then
            current_name=$(get_name "$tuple")

            if [ "$1" == "smart" ] || [ "$2" == "smart" ]; then
                kill_pg_by_name "$current_name" "$1" smart
            else 
                kill_pg_by_name "$current_name" "$1"
            fi
        fi
    done
}

# kill_pg_by_name stops the given Postgres. 
# $1 = Postgres instance name according to ID_IP_NODES.sh
# $2 = "-c" If given will only kill the subscriber. If omitted this function will also scale the service down by one to avoid a restart.
# $2 or $3 = "smart". Will stop postgres via a smart shutdown
# Context: TEST, UPGRADE
kill_pg_by_name(){
    if [ "$2" == "smart" ] || [ "$3" == "smart" ]; then
        stop_pg_container "$1" smart
    else 
        stop_pg_container "$1"
    fi
    
    if [ "$2" != "-c" ]; then
        current_sub_count=$(($current_sub_count - 1))
        if [ "$current_sub_count" -lt 0 ]; then
            current_sub_count=0
        fi
        IFS='.' read service_name replic_number <<< "$1"
        scale_service_with_timeout $service_name $current_sub_count
    fi
}

# get_log returns the Docker log of a given container
# $1 = Postgres instance name according to ID_IP_NODES.sh
# Context: TEST
get_log(){
    tuple=$(get_tuple_from_name $1)
    if [ -z $tuple ]; then
        echo "Container $1 was not found, is it really active?"
    else
        node=$(get_node $tuple)
        id=$(get_id $tuple)
        $SSH_CMD_TIMEOUT root@$node "docker logs $id"
    fi
}

# get_notify_log returns the Keepaliveds notify_log.txt on the given Docker Swarm node
# $1 = Docker Swarm nodes hostname
# Context: TEST
get_notify_log(){
    $SSH_CMD root@$1 cat /etc/keepalived/notify_log.txt
}

# wait_for_all_pg_to_boot waits until all Postgres instances are up and running.
# Context: SETUP, TEST, UPGRADE
wait_for_all_pg_to_boot(){
    for tuple in $(get_all_tuples); do
        container_id=$(get_id "$tuple")
        node=$(get_node "$tuple")
        while true; do
            result="$($SSH_CMD root@$node docker exec $container_id pg_isready)"
            if [[ "$result" == *"- accepting connections"* ]]; then
                printf "."
                break
            fi
            sleep 2s
        done
    done
    echo ""
}

# start_new_subscriber starts a new Postgres subscriber by scaling the given service up by one.
# $1 = Docker Swarm Servicename
# Context: TEST, UPGRADE
start_new_subscriber(){
    # Scale the subscriber service up by one
    # Test: (Re-) Start of Subscribers that creates subscription
    # Test: Subscriber also receives als data before start.
    echo "This may take a few moments and consider deployment-constraints / ports usage which could prevent a success!"
    current_sub_count=$(($current_sub_count + 1))
    scale_service_with_timeout "$1" $current_sub_count
    wait_for_all_pg_to_boot
}

# return_from_trap used to make it possible for the user to cancel observe_container_status
# Context: SETUP, TEST, UPGRADE
return_from_trap(){
    echo "Aborting Observation"
    trap - SIGINT
    $0 # Restart script.
}

# observe_container_status returns the state (version labels, ids, ips, roles, postgres instances) of the current cluster 
# Context: SETUP, TEST, UPGRADE
observe_container_status(){
    trap return_from_trap SIGINT
    while true; 
    do
        echo "----------- $(date) ----------"
        update_id_ip_nodes
        get_current_node_ips
        echo ""
        print_id_ip_nodes
        sleep 4s
    done
}

# upgrade_provider upgrades the provider. BEWARE this only works under the assumption that there is at most one provider in the system! 
# $1 = total number of new (v10) postgres instances after upgrade
# Context: TEST, UPGRADE
upgrade_provider(){
    # TODO adjust to upgrade_subscriber code (e.g. get new v10 instance count from current count + 1)

    # 1. Shutdown Provider Smart
    prov_tuple="$(get_all_provider)"
    prov_node=$(get_node "$prov_tuple")
    prov_id=$(get_id "$prov_tuple")
    $SSH_CMD root@$prov_node "docker exec $prov_id pg_ctl stop -m smart"
    
    scale_service_with_timeout "pg95_db" 0 1> /dev/null

    # 2. Adjust Cluster & Node Labels
    set_cluster_version 10.13

    # This code,again, expects that the provider is the last v9.5 db!
    set_version_label_of_IP_to_10 $prov_node

    # 3. Increase v10 Instance count by one.
    scale_service_with_timeout "pg10_db" $1 1> /dev/null
    
    update_id_ip_nodes
    sleep 30s
}

# upgrade_subscriber upgrades a given subscriber.
# $1 = name of the old (v9.5) postgres instance that will ge upgraded (replaced with a new (v10) one)
# $2 = total number of new (v10) postgres instances after upgrade
# Context: TEST, UPGRADE
upgrade_subscriber(){
    # TODO make $2 deprecated by getting current replica count from docker service directly and then increase by one to get total number of new postgres instances.
    sub_tuple=$(get_tuple_from_name $1)
    sub_node=$(get_node $sub_tuple)
    kill_pg_by_name "$1" 1> /dev/null

    set_version_label_of_IP_to_10 $sub_node
    scale_service_with_timeout "pg10_db" $2 1> /dev/null

    update_id_ip_nodes
    sleep 30s
}