#!/bin/sh

# Depends on (will be sourced by using script):
# - ssh_scp.sh

EXTRACT_TOKEN_FAILURE_RESULT="NOT FOUND"

extract_token() {
    result="$EXTRACT_TOKEN_FAILURE_RESULT"

    token_raw=($(echo $1 | grep -o "SWMTKN.*"))
    if [ "${#token_raw[@]}" -gt 0 ]; then
        result=${token_raw[0]}
    fi

    echo $result
}

set_label(){
    # Do not delete the label before setting it, otherwise swarm most certainly will shutdown depended containers.
    $SSH_CMD root@$manager_node docker node update --label-add $2=$3 $1
}

set_label_version() {
    hostname=$(get_hostname $1)
    if [ -z "$hostname" ]; then
        echo "Could not find the hostname for index $1"
        exit 1
    else
        set_label $hostname "pg_ver" "$2" 1> /dev/null
    fi
}

get_label_version(){
    hostname=$(get_hostname $1)
    $SSH_CMD root@$manager_node "docker node inspect -f '{{ .Spec.Labels.pg_ver }}' $hostname"
}

update_labels(){
    for current_hostname in $all_hostnames; do
        set_label $current_hostname "pg_ver" "9.5"
    done
}

update_stacks() {
    SCP_CMD_FOR_EACH_NODE ./stacks/stack95.yml /root/
    SCP_CMD_FOR_EACH_NODE ./stacks/stack10.yml /root/
    SCP_CMD_FOR_EACH_NODE ./stacks/portainer-agent-stack.yml /root/
}

gather_id() {
    $SSH_CMD $1 docker ps -f "name=$2" -q
}

gather_ip() {
    $SSH_CMD $1 docker inspect -f '{{.NetworkSettings.Networks.pg_pgnet.IPAddress}}' $2
}

gather_running_containers() {
    $SSH_CMD $1 'docker ps --format "table {{.ID}}\t{{.Names}}"'
}

# $1 = name // $2 = local location // $3 = remote location
reset_config() {
    $SSH_CMD root@$manager_node "docker config rm $1" 2>/dev/null
    $SCP_CMD $2 root@$manager_node:$3
    $SSH_CMD root@$manager_node "docker config create $1 $3"
}

build_images() {
    SCP_CMD_FOR_EACH_NODE "../custom_image/9.5.18.dockerfile" /etc/
    SCP_CMD_FOR_EACH_NODE "../custom_image/10.13.dockerfile" /etc/
    SCP_CMD_FOR_EACH_NODE "../custom_image/docker-entrypoint.sh" /etc/
    SSH_CMD_FOR_EACH_NODE "chmod +x /etc/docker-entrypoint.sh"

    SSH_CMD_FOR_EACH_NODE "docker build /etc/ -f /etc/9.5.18.dockerfile -t mypglog:9.5-raw"
    SSH_CMD_FOR_EACH_NODE "docker build /etc/ -f /etc/10.13.dockerfile -t mypglog:10-raw"
}

set_configs() {
    reset_config "tables" "./postgres/table_setup.sql" "/etc/table_setup.sql"

    reset_config "sub_config" "./postgres/sub_postgresql.conf" "/etc/sub_postgresql.conf"
}

clean_docker() {
    $SSH_CMD root@$manager_node "docker stack rm pg95"
    $SSH_CMD root@$manager_node "docker stack rm pg10"
    sleep 10s #Wait till everything is deleted

    SSH_CMD_FOR_EACH_NODE "docker rm $(docker ps -aq) -f"
    SSH_CMD_FOR_EACH_NODE "docker volume prune -f"
}

deploy_stack() {
    $SSH_CMD root@$manager_node "docker stack deploy -c stack95.yml pg95"
    $SSH_CMD root@$manager_node "docker stack deploy -c stack10.yml pg10"
    $SSH_CMD root@$manager_node "docker stack deploy -c portainer-agent-stack.yml portainer"
    sleep 15s #Wait till everything has started

    echo "-- Connect to Portainer at: http://$manager_node:9000/"
}

start_swarm() {
    SSH_CMD_FOR_EACH_NODE "systemctl start docker"
    SSH_CMD_FOR_EACH_NODE "docker swarm leave -f"

    full_init_msg=$($SSH_CMD root@$manager_node "docker swarm init --advertise-addr $manager_node")
    TOKEN=$(extract_token "$full_init_msg")

    for current_node in $other_nodes; do
        $SSH_CMD root@$current_node "docker swarm join --token $TOKEN $manager_node:2377"
    done
}

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

# TODO This variable is intentionally the same as in id_ip_nodes.sh, but this seems very ugly!
current_sub_count=1

kill_postgres(){
    CURRENT_INFO=$(get_node_and_id_from_name "$1")
    IFS=',' read CURRENT_NODE CURRENT_ID <<< "${CURRENT_INFO}"

    $SSH_CMD root@$CURRENT_NODE "docker rm -f $CURRENT_ID"
}

# kill_provider only works under the assumption that there is at most one provider in the system!
# Otherwise it will kill all providers.
kill_provider(){
    for tuple in $(get_all_tuples); do
        current_role=$(get_role "$tuple")
        if [[ $current_role == "prov" ]]; then
            current_name=$(get_name "$tuple")

            kill_subscriber "$current_name" "$1"
        fi
    done
}

# Kill Subscriber (as harsh as possible) and immediately Scale the subscriber service down by one so Swarm doesn't directly start a new subscriber
kill_subscriber(){
    # TODO make it possible via parameter to shutdown "smart"
    # TODO rename function since it basically can kill subscriber and provider instances.

    kill_postgres "$1" 
    echo Current Count = $current_sub_count
    
    if [ "$2" != "-c" ]; then
        current_sub_count=$(($current_sub_count - 1))
        if [ "$current_sub_count" -lt 0 ]; then
            current_sub_count=0
        fi
        IFS='.' read service_name replic_number <<< "$1"
        scale_service_with_timeout $service_name $current_sub_count
    fi
}

get_log(){
    CURRENT_INFO=$(get_node_and_id_from_name "$1")
    if [ -z $CURRENT_INFO ]; then
        echo "Container $1 was not found, is it really active?"
    else
        IFS=',' read CURRENT_NODE CURRENT_ID <<< "${CURRENT_INFO}"
        $SSH_CMD_TIMEOUT root@$CURRENT_NODE "docker logs $CURRENT_ID"
    fi
}

get_notify_log(){
    $SSH_CMD root@$1 cat /etc/keepalived/notify_log.txt
}

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

start_new_subscriber(){
    # Scale the subscriber service up by one
    # Test: (Re-) Start of Subscribers that creates subscription
    # Test: Subscriber also receives als data before start.
    echo "This may take a few moments and consider deployment-constraints / ports usage which could prevent a success!"
    current_sub_count=$(($current_sub_count + 1))
    scale_service_with_timeout "$1" $current_sub_count
    wait_for_all_pg_to_boot
}

return_from_trap(){
    echo "Aborting Observation"
    trap - SIGINT
    $0 # Restart script.
}

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

# Sets the version label ('pg_ver') of a given host to 10
# $1 = Host IP
update_label_version_to_10(){
    index=$(get_index_of_dsn_node $1)
    if ! [ -z "$index" ] && [ $index -ge 0 ]; then
        set_label_version $index 10
    fi
}

# $1 = total number of new (v10) postgres instances after upgrade
upgrade_provider(){
    # TODO adjust to upgrade_subscriber code

    # 1. Shutdown Provider Smart
    prov_tuple="$(get_all_provider)"
    prov_node=$(get_node "$prov_tuple")
    prov_id=$(get_id "$prov_tuple")
    $SSH_CMD root@$prov_node "docker exec $prov_id pg_ctl stop -m smart"
    
    # TODO write down in documentation that this expects that the provider is the last v9.5 db!
    scale_service_with_timeout "pg95_db" 0 1> /dev/null

    # 2. Adjust Cluster & Node Labels
    set_cluster_version 10.13

    # Beware that this only changes the node label of the provider node! 
    # This code,again, expects that the provider is the last v9.5 db!
    update_label_version_to_10 $prov_node

    # 3. Increase v10 Instance count by one.
    scale_service_with_timeout "pg10_db" $1 1> /dev/null
    update_id_ip_nodes
    sleep 30s
}

# $1 = name of the old (v9.5) postgres instance that will ge upgraded (replaced with a new (v10) one)
# $2 = total number of new (v10) postgres instances after upgrade
upgrade_subscriber(){
    # TODO make $2 deprecated by getting current replica count from docker service directly and then increase by one to get total number of new postgres instances.
    sub_tuple=$(get_tuple_from_name $1)
    sub_node=$(get_node $sub_tuple)
    kill_subscriber "$1" 1> /dev/null

    update_label_version_to_10 $sub_node
    scale_service_with_timeout "pg10_db" $2 1> /dev/null

    update_id_ip_nodes
    sleep 30s
}

update_cluster_version(){
    SSH_CMD_FOR_EACH_NODE "echo $1 > /etc/keepalived/cluster_version.txt"
}
