# This file is used to configure the code to work with different clusters and setups.

# Nodes 
# Nodes are all Docker Swarm Nodes in representation as their IPs, they are not allowed to include spaces!
# The 'manager_node' is the IP of the Docker Swarm Manager Nodes, it is expected there is only one Manager in the cluster.
# The 'other_nodes' are all IPs of Docker Swarm Nodes that are not the manager. 
# The 'all_nodes' is the combination of the both variables described above.
# The 'hostnames' must be the hostnames of the Docker Swarm Nodes, in the same order as in 'all_nodes'!

manager_node="192.168.99.107"
other_nodes="192.168.99.108"
all_nodes="$manager_node $other_nodes" 
all_hostnames="docker-swarm-node1.localdomain docker-swarm-node2.localdomain"
