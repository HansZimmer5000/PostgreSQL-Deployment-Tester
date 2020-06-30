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

update_stacks() {
    SCP_CMD_FOR_EACH_NODE ./stacks/stack.yml /root/
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
    $SSH_CMD root@$MANAGER_NODE "docker config rm $1" 2>/dev/null
    $SCP_CMD $2 root@$MANAGER_NODE:$3
    $SSH_CMD root@$MANAGER_NODE "docker config create $1 $3"
}

# $1 = DSN Zahl des Init Nodes, $2-4 sind alle DSN Zahlen
set_init_label() {
    $SSH_CMD root@$MANAGER_NODE docker node update --label-add init_node=false docker-swarm-node$2.localdomain
    $SSH_CMD root@$MANAGER_NODE docker node update --label-add init_node=false docker-swarm-node$3.localdomain
    $SSH_CMD root@$MANAGER_NODE docker node update --label-add init_node=false docker-swarm-node$4.localdomain

    $SSH_CMD root@$MANAGER_NODE docker node update --label-add init_node=true docker-swarm-node$1.localdomain
}

build_images() {
    SCP_CMD_FOR_EACH_NODE "../custom_image/9.5.18.dockerfile" /etc/
    SCP_CMD_FOR_EACH_NODE "../custom_image/docker-entrypoint.sh" /etc/
    SSH_CMD_FOR_EACH_NODE "chmod +x /etc/docker-entrypoint.sh"

    SSH_CMD_FOR_EACH_NODE "docker build /etc/ -f /etc/9.5.18.dockerfile -t mypglog:9.5-raw"
}

set_configs() {
    reset_config "tables" "./postgres/table_setup.sql" "/etc/table_setup.sql"

    reset_config "sub_config" "./postgres/sub_postgresql.conf" "/etc/sub_postgresql.conf"
}

clean_docker() {
    $SSH_CMD root@$MANAGER_NODE "docker stack rm pg"
    sleep 10s #Wait till everything is deleted

    SSH_CMD_FOR_EACH_NODE "docker rm $(docker ps -aq) -f"
    SSH_CMD_FOR_EACH_NODE "docker volume prune -f"
}

deploy_stack() {
    $SSH_CMD root@$MANAGER_NODE "docker stack deploy -c stack.yml pg"
    $SSH_CMD root@$MANAGER_NODE "docker stack deploy -c portainer-agent-stack.yml portainer"
    sleep 15s #Wait till everything has started

    echo "-- Connect to Portainer at: http://$dsn1_node:9000/"
}

start_swarm() {
    SSH_CMD_FOR_EACH_NODE "systemctl start docker"
    SSH_CMD_FOR_EACH_NODE "docker swarm leave -f"

    full_init_msg=$($SSH_CMD root@$MANAGER_NODE "docker swarm init --advertise-addr $dsn1_node")
    TOKEN=$(extract_token "$full_init_msg")

    $SSH_CMD root@$dsn2_node "docker swarm join --token $TOKEN $dsn1_node:2377"
    #ADJUSTMENT: $SSH_CMD root@dsn3 "docker swarm join --token $TOKEN $dsn1_node:2377"
}

check_swarm() {
    nodes=$($SSH_CMD root@$MANAGER_NODE "docker node ls")
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
