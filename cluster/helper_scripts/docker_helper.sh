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
    set_label "docker-swarm-node$1.localdomain" "pg_ver" "$2" 1> /dev/null
}

get_label_version(){
    $SSH_CMD root@$manager_node "docker node inspect -f '{{ .Spec.Labels.pg_ver }}' docker-swarm-node$1.localdomain"
}

update_labels(){
    set_label "docker-swarm-node1.localdomain" "pg_ver" "9.5"
    set_label "docker-swarm-node2.localdomain" "pg_ver" "9.5"
    set_label "docker-swarm-node3.localdomain" "pg_ver" "9.5"
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

    echo "-- Connect to Portainer at: http://$dsn1_node:9000/"
}

start_swarm() {
    SSH_CMD_FOR_EACH_NODE "systemctl start docker"
    SSH_CMD_FOR_EACH_NODE "docker swarm leave -f"

    full_init_msg=$($SSH_CMD root@$manager_node "docker swarm init --advertise-addr $dsn1_node")
    TOKEN=$(extract_token "$full_init_msg")

    $SSH_CMD root@$dsn2_node "docker swarm join --token $TOKEN $dsn1_node:2377"
    #ADJUSTMENT: $SSH_CMD root@dsn3 "docker swarm join --token $TOKEN $dsn1_node:2377"
}

check_swarm() {
    nodes=$($SSH_CMD root@$manager_node "docker node ls")
    if [ -z "$nodes" ]; then
        echo "Is Manager Node ready? Aborting"
        exit 1
    elif [[ "$nodes" != *"docker-swarm-node2"* ]]; then
        echo "Is Node 2 ready? Aborting"
        exit 1
    else
        echo "Both Nodes are up!"
    fi
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
