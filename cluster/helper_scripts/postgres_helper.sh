# !/bin/sh 
# This is meant to be 'sourced'!

# execute_sql will execute an SQL statement on a given Postgres container on a given Docker Swarm node in the database 'testdb'
# $1 = Docker Sawrm nodes IP
# $2 = Container ID 
# $3 = SQL statement
# Context: SETUP, TEST, UPGRADE
execute_sql() {
    $SSH_CMD root@$1 docker exec $2 "psql -v ON_ERROR_STOP=1 --username postgres --dbname testdb -c '$3'"
}


# reconnect_subscriber reconnects a subscriber to the Provider.
# $1 = Docker Swarm Node
# $2 = Container ID
# $3 = Container IP in the pgnet Network (is the basis for the pglogical subscription ID)
# Context: TEST, UPGRADE
reconnect_subscriber(){
    SUBSCRIPTION_ID="subscription${3//./}"
    $SSH_CMD root@$1 "/etc/reconnect.sh" $2 $SUBSCRIPTION_ID
}


# reconnect_all_subscriber reconnects all subscriber to the Provider.
# Context: TEST, UPGRADE
reconnect_all_subscriber(){
    for tuple in $(get_all_tuples); do
        current_role=$(get_role "$tuple")
        current_node=$(get_node "$tuple")
        current_id=$(get_id "$tuple")
        current_ip=$(get_ip "$tuple")
        if [[ $current_role == sub ]]; then
            reconnect_subscriber $current_node $current_id $current_ip 1> /dev/null
        fi
    done
}