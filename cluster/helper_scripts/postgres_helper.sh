# !/bin/sh 
# This is meant to be 'sourced'!

# POSTGRESQL
################

POSTGRES_USER="postgres"
POSTGRES_DB="testdb"

# execute_sql will execute an SQL statement on a given Postgres container on a given Docker Swarm node in the database 'testdb'
# $1 = Docker Sawrm nodes IP
# $2 = Container ID 
# $3 = SQL statement
# Context: SETUP, TEST, UPGRADE
execute_sql() {
    $SSH_CMD root@$1 docker exec $2 "psql -v ON_ERROR_STOP=1 --username postgres --dbname testdb -c '$3'"
}

# get_local_table returns the content of the table 'testtable' in the database 'testdb' of the given Postgres instance
# $1 = Docker Sawrm nodes IP
# $2 = Container ID 
# Context: TEST
get_local_table(){
    # If 'SELECT *' is used, sh tries to set local folders and files as "*", so we specified 'SELECT id ...'.
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

# get_table returns the content of the table 'testtable' in the database 'testdb' of the given Postgres instance
# $1 = Postgres Container name
# Context: TEST
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

# get_local_table returns the content of the table 'testtable' in the database 'testdb' of all Postgres instances
# Context: TEST
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

# add_entry adds a row to the table 'testtable' in the database 'testdb' on the given Postgres instance
# $1 = Docker Sawrm nodes IP
# $2 = Container ID 
# $3 = ID of new row (the id is the only column)
# Context: TEST
add_entry() {
    execute_sql $1 $2 "INSERT INTO testtable (id) VALUES ($3);"
}

# remove_entry deletes a row of the table 'testtable' in the database 'testdb' on the given Postgres instance
# $1 = Docker Sawrm nodes IP
# $2 = Container ID 
# $3 = ID of the row 
# Context: TEST
remove_entry() {
    execute_sql $1 $2 "DELETE FROM testtable WHERE (id=$3);"
}

# remove_all_entries deletes all rows of the table 'testtable' in the database 'testdb' on the given Postgres instance
# $1 = Docker Sawrm nodes IP
# $2 = Container ID 
# Context: TEST
remove_all_entries(){
    execute_sql $1 $2 "DELETE FROM testtable;"
}

# clear_all_local_tables deletes all rows of the table 'testtable' in the database 'testdb' on all Postgres instances
# Context: TEST
clear_all_local_tables(){
    for tuple in $(get_all_tuples); do
        CURRENT_NAME=$(get_name "$tuple")
        CURRENT_NODE=$(get_node "$tuple")
        CURRENT_ID=$(get_id "$tuple")
        echo "Cleaning testtable in $CURRENT_NAME"
        remove_all_entries $CURRENT_NODE $CURRENT_ID
    done
}

# check_equal_tables checks if the given input of all tables 'testtable' in the database 'testdb' of all Postgres instances are equal.
# $1 = Content of all 'testtable's as output of 'get_all_local_tables'
# Context: TEST
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

# check_tables checks if the content of all tables 'testtable' in the database 'testdb' of all Postgres instances are equal or not and matches that with a given boolean value.
# $1 = Bool expectation if tables are equal or not.
# Context: TEST
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

# check_tables_and_clean_up checks if the content of all tables 'testtable' in the database 'testdb' of all Postgres instances are equal or not and matches that with a given boolean value. Eventually will remove the content.
# $1 = Bool expectation if tables are equal or not.
# Context: TEST
check_tables_and_clean_up(){
    result=$(check_tables $1)
    if [[ $result == true ]]; then
        echo "Role and replication confirmed"
    else   
        echo "$result"
    fi
    clear_all_local_tables 1> /dev/null
}

# check_provider adds entries via a given Postgres instance on a given host and checks if the content of all tables 'testtable' in the database 'testdb' of all Postgres instances are equal. Eventually will remove the content.
# $1 = Docker Sawrm nodes IP
# $2 = Container ID 
# Context: TEST
check_provider(){
    # Insert something into Provider -> all should receive this new entry
    echo "-- Checking Provider"
    add_entry $1 $2 7 1> /dev/null
    add_entry $1 $2 49 1> /dev/null
    sleep 2s
    check_tables_and_clean_up true
}

# check_subscriber adds entries via a given Postgres instance on a given host and checks if the content of all tables 'testtable' in the database 'testdb' of all Postgres instances are NOT equal. Eventually will remove the content.
# $1 = Docker Sawrm nodes IP
# $2 = Container ID 
# Context: TEST
check_subscriber(){
    # Insert something into subscriber -> no one should receive this entry
    echo "-- Checking $1"
    add_entry $2 $3 3 1> /dev/null
    sleep 2s
    check_tables_and_clean_up false #can be false if sync works correct
}

# check_roles checks if the determined Postgres roles are correct by adding entries to tables and see if these are replicated. If entries are inserted on a Provider Postgres it is expected that every Subscriber also receives this info. If entries are inserted on a Subscriber Postgres it is expected that only this Subscriber has the new data.
# Context: TEST
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

# reconnect_subscriber reconnects a subscriber to the Provider.
# $1 = Docker Swarm Node
# $2 = Container ID
# $3 = Container IP in the pgnet Network (is the basis for the pglogical subscription ID)
# Context: TEST
reconnect_subscriber(){
    SUBSCRIPTION_ID="subscription${3//./}"
    $SSH_CMD root@$1 "/etc/reconnect.sh" $2 $SUBSCRIPTION_ID
}

# reconnect_all_subscriber reconnects all subscriber to the Provider.
# Context: TEST
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
