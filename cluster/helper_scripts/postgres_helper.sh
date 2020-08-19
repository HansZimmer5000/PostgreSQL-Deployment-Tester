# !/bin/sh 
# This is meant to be 'sourced'!

# POSTGRESQL
################

POSTGRES_USER="postgres"
POSTGRES_DB="testdb"

# $1 = node // $2 = Container ID // $3 = Sql command
execute_sql() {
    $SSH_CMD root@$1 docker exec $2 "psql -v ON_ERROR_STOP=1 --username postgres --dbname testdb -c '$3'"
}

# $1 = node // $2 = Container ID
get_local_table(){
    # If 'SELECT *' is used, sh tries to set local folders and files as "*".
    TABLE=$(execute_sql $1 $2 "SELECT id FROM testtable;")
    TABLE_LEN=$(echo "$TABLE" | wc -w)
    ENTRIES=""
    INDEX=0

    for word in $TABLE; do 
        if [ $INDEX -eq $((TABLE_LEN - 2)) ]; then
            break
        elif [ $INDEX -eq 2 ]; then
            ENTRIES="$word"
        elif [ $INDEX -gt 2 ]; then
            ENTRIES="$ENTRIES,$word"
        fi
        INDEX=$((INDEX+1))
        # 0 = tablename
        # 1 = "----"
        # 2 = first entry
        # n-1 = "(" rowcount
        # n = "row)"
    done
    echo $ENTRIES
}

get_table(){
    tuple=$(get_tuple "$1")
    if [ -z $tuple ]; then
        echo "Container $1 was not found, is it really active?"
    else
        node=$(get_node $tuple)
        id=$(get_id $tuple)
        get_local_table $node $id
    fi
}

get_all_local_tables(){
    # Print local table of Provider and Subscribers
    print_id_ip_nodes 1> /dev/null

    TABLES=""

    for tuple in $(get_all_tuples); do
        CURRENT_NAME=$(get_name "$tuple")
        CURRENT_NODE=$(get_node "$tuple")
        CURRENT_ID=$(get_id "$tuple")
        if [ "$CURRENT_NODE" != "" ];
        then
            TABLES="$TABLES $CURRENT_NAME:$(get_local_table $CURRENT_NODE $CURRENT_ID)"
        fi
    done
    echo $TABLES
}

# $1 = node // $2 = Container ID // $3 = id of new entry
add_entry() {
    execute_sql $1 $2 "INSERT INTO testtable (id) VALUES ($3);"
}

# $1 = node // $2 = Container ID // $3 = entry id
remove_entry() {
    execute_sql $1 $2 "DELETE FROM testtable WHERE (id=$3);"
}

# $1 = node // $2 = Container ID 
remove_all_entries(){
    execute_sql $1 $2 "DELETE FROM testtable;"
}

clear_all_local_tables(){
    # Print local table of Provider and Subscribers

    for tuple in $(get_all_tuples); do
        CURRENT_NAME=$(get_name "$tuple")
        CURRENT_NODE=$(get_node "$tuple")
        CURRENT_ID=$(get_id "$tuple")
        echo "Cleaning testtable in $CURRENT_NAME"
        remove_all_entries $CURRENT_NODE $CURRENT_ID
    done
}

check_equal_tables(){
    IS_EQUAL=true
    TABLE_NO=0

    for table in $1; do
        IFS=':' read CURRENT_DB CURRENT_TABLE <<< "${table}"
        if [ -z $BEFORE_TABLE ]; then # Does not work right when all are empty except last.
            if [ $TABLE_NO -gt 0 ]; then
                IS_EQUAL=false
                break
            else
                BEFORE_TABLE="$CURRENT_TABLE" 
            fi
        elif [ "$CURRENT_TABLE" != "$BEFORE_TABLE" ]; then
            IS_EQUAL=false
            break
        fi
        TABLE_NO=$((TABLE_NO+1))
    done

    echo $IS_EQUAL
}

# $1 = expected bool result
check_tables(){
    TABLES=$(get_all_local_tables)
    IS_EQUAL=$(check_equal_tables "$TABLES")
    
    if [ "$IS_EQUAL" == "$1" ]; then
        echo true
    else
        echo "Table check was not $1 with table:"
        echo $TABLES
    fi 
}

check_tables_and_clean_up(){
    result=$(check_tables $1)
    if [[ $result == true ]]; then
        echo "Role and replication confirmed"
    else   
        echo "$result"
    fi
    clear_all_local_tables 1> /dev/null
}

check_provider(){
    # Insert something into Provider -> all should receive this new entry
    echo "-- Checking Provider"
    add_entry $1 $2 7 1> /dev/null
    add_entry $1 $2 49 1> /dev/null
    sleep 2s
    check_tables_and_clean_up true
}

check_subscriber(){
    # Insert something into subscriber -> no one should receive this entry
    echo "-- Checking $1"
    add_entry $2 $3 3 1> /dev/null
    sleep 2s
    check_tables_and_clean_up false #can be false if sync works correct
}

check_roles() {
    for tuple in $(get_all_tuples); do
        CURRENT_NAME=$(get_name "$tuple")
        CURRENT_ROLE=$(get_role "$tuple")
        CURRENT_NODE=$(get_node "$tuple")
        CURRENT_ID=$(get_id "$tuple")
        if [[ $CURRENT_ROLE == "prov" ]]; then
            check_provider $CURRENT_NODE $CURRENT_ID
        else
            check_subscriber $CURRENT_NAME $CURRENT_NODE $CURRENT_ID
        fi
    done
}

reconnect_subscriber(){
    SUBSCRIPTION_ID="subscription${3//./}"
    $SSH_CMD root@$1 "/etc/reconnect.sh" $2 $SUBSCRIPTION_ID
}

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

promote_subscriber(){
    container_id=$(get_id $1)
    container_ip=$(get_ip $1)
    subscription_id="subscription${container_ip//./}"

    /etc/keepalived/promote.sh $container_id $subscription_id
}
