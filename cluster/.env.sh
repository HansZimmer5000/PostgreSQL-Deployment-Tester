#ADJUSTMENT: replace dsn1,2,3 with actual IPs
# Nodes are not allowed to have spaces in their names!
dsn1_node="192.168.99.107"
dsn2_node="192.168.99.108"
dsn3_node=""

MANAGER_NODE="$dsn1_node" 
OTHER_NODES="$dsn2_node $dsn3_node" 
ALL_NODES="$MANAGER_NODE $OTHER_NODES" 