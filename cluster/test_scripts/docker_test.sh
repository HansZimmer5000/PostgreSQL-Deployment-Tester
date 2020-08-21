#!/bin/sh

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