#!/bin/sh

# This script is currently unused but it may be useful in the future!

remove_old_provider(){
    docker exec $1 psql -e -v ON_ERROR_STOP=1 --username postgres --dbname testdb -c "SELECT pglogical.drop_subscription('$2');"

    docker exec $1 psql -e -v ON_ERROR_STOP=1 --username postgres --dbname testdb -c "SELECT pglogical.drop_node('provider95');"
}

create_subscriber(){
    docker exec $1 psql -e -v ON_ERROR_STOP=1 --username postgres --dbname testdb -c "
    SELECT pglogical.create_node(
            node_name := 'subscriber95',
            dsn := 'host=$2 port=5432 dbname=testdb password=pass user=postgres'
        );"

    docker exec $1 psql -e -v ON_ERROR_STOP=1 --username postgres --dbname testdb -c "
    SELECT pglogical.create_subscription(
            subscription_name := 'subscription$3',
            provider_dsn := 'host=$4 port=5432 dbname=testdb password=pass user=postgres'
        );"

    #echo "Wait for sync"
    # Skip this part as this is currently only used for upgrading.
    # TODO BUT may use flags in the future to signal if this "waiting" is needed or not.
    
    #docker exec $1 psql -e -v ON_ERROR_STOP=1 --username postgres --dbname testdb -c "SELECT pglogical.wait_for_subscription_sync_complete('subscription$3');"
        


    #SELECT pglogical.show_subscription_status(); ""
}

container_id=$1
subscriber_ip=$2
subscription_id="subscription${subscriber_ip//./}"
virtual_ip="192.168.99.149"

echo "Demoting with:
container_id($container_id)
subscriber_ip($subscriber_ip)
subscription_id($subscription_id)
virtual_ip($virtual_ip)
"

remove_old_provider $container_id $subscription_id
create_subscriber $container_id $subscriber_ip $subscription_id $virtual_ip
