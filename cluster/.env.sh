# This file is used to configure the code to work with different clusters and setups.

# Nodes 
# Nodes are all Docker Swarm Nodes in representation as their IPs, they are not allowed to include spaces!
# TODO remove dsn1_node and other variables and only have "manager_node" and "other_nodes", replace uses of these variables with a function for "random other node" or similar.
# The 'manager_node' is the IP of the Docker Swarm Manager Nodes, it is expected there is only one Manager in the cluster.
# The 'other_nodes' are all IPs of Docker Swarm Nodes that are not the manager. 
# The 'all_nodes' is the combination of the both variables described above.

dsn1_node="192.168.99.107"
dsn2_node="192.168.99.108"
dsn3_node=""

manager_node="$dsn1_node" 
other_nodes="$dsn2_node $dsn3_node" 
all_nodes="$manager_node $other_nodes" 