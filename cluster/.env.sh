# This file is used to configure the code to work with different clusters and setups.

# Nodes 
# Nodes are all Docker Swarm Nodes in representation as their IPs, they are not allowed to include spaces!
# TODO remove dsn1_node and other variables and only have "manager_node" and "other_nodes", replace uses of these variables with a function for "random other node", "1 = first node in all_nodes, ..." or similar.
# The 'manager_node' is the IP of the Docker Swarm Manager Nodes, it is expected there is only one Manager in the cluster.
# The 'other_nodes' are all IPs of Docker Swarm Nodes that are not the manager. 
# The 'all_nodes' is the combination of the both variables described above.
# The 'hostnames' must be the hostnames of the Docker Swarm Nodes, in the same order as in 'all_nodes'!

#dsn1_node="192.168.99.107"
#dsn2_node="192.168.99.108"
#dsn3_node=""

manager_node="192.168.99.107" #"$dsn1_node" 
other_nodes="192.168.99.108" #"$dsn2_node $dsn3_node" 
all_nodes="$manager_node $other_nodes" 
all_hostnames="docker-swarm-node1.localdomain docker-swarm-node2.localdomain"

# The following functions are used to retrieve certain IPs / hostnames in a exact location within 'all_nodes' and 'all_hostnames'.
# TODO move to a better fitting location
get_dsn_node(){
    arr=($all_nodes)
    echo ${arr[$1]}
}

get_hostname(){
    arr=($all_hostnames)
    echo ${arr[$1]}
}

get_node_count(){
    arr=($all_hostnames)
    echo ${#arr[@]}
}

get_index_of_dsn_node(){
    index=0
    for current_node in $all_nodes; do
        if [[ "$1" == "$current_node" ]]; then
            echo $index
            break
        fi
        index=$((index+1))
    done
}