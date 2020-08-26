# !/bin/sh

# $1 = Container Name
promote_sub(){
    tuple=$(get_tuple_from_name $1)
    container_id=$(get_id $tuple)
    ip=$(get_ip $tuple)
    subscription_id="subscription${ip//./}"
    ./postgres/promote.sh $container_id $subscription_id
}

execute_sql() {
    docker exec $1 psql -v ON_ERROR_STOP=1 --username postgres --dbname $POSTGRES_DB -c "$2"
}

remove_old_provider(){
    tuple=$(get_tuple_from_name $1)
    container_id=$(get_id $tuple)
    ip=$(get_ip $tuple)
    subscription_id="subscription${ip//./}"

    #docker exec $container_id psql -e -v ON_ERROR_STOP=1 --username postgres --dbname $POSTGRES_DB -c "SELECT pglogical.drop_subscription('$subscription_id');"

    docker exec $container_id psql -e -v ON_ERROR_STOP=1 --username postgres --dbname $POSTGRES_DB -c "SELECT pglogical.drop_node('provider95');"

    docker exec $container_id psql -e -v ON_ERROR_STOP=1 --username postgres --dbname $POSTGRES_DB -c "DROP EXTENSION pglogical;"
}