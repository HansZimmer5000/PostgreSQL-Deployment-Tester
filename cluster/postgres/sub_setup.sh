#!/bin/bash

wait_for_startup() {
    echo "Waiting for this subscriber to startup, sleeping 1s each:"

    pg_is_starting=true
    while $pg_is_starting; do
        printf "."
        sleep 1s

        status=$(pg_ctl status)
        if [[ "$status" == *"pg_ctl: server is running (PID:"* ]]; then
            pg_is_starting=false
        fi
    done
}

get_ip() {
    IPs=($(ifconfig eth1 | grep "inet"))
    echo ${IPs[1]}
}

init_this_subscriber() {
    wait_for_startup 
    SUBSCRIBER_IP=$(get_ip)
    SUBSCRIPTION_ID="${SUBSCRIBER_IP//./}"

    echo "Using IP ($SUBSCRIBER_IP) and ID ($SUBSCRIPTION_ID)"

    echo "1/3 Creating local pglogical node"
    psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" -c "
        -- PG LOGICAL
        CREATE EXTENSION pglogical;

        SELECT pglogical.create_node(
            node_name := 'subscriber95',
            dsn := 'host=$SUBSCRIBER_IP port=5432 dbname=testdb password=pass user=postgres'
        );"

    echo "2/3 Creating subscription"
    psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" -c "
        -- user Docker Service Name as host url
        SELECT pglogical.create_subscription(
            subscription_name := 'subscription$SUBSCRIPTION_ID',
            provider_dsn := 'host=192.168.99.149 port=5433 dbname=testdb password=pass user=postgres'
        );"
        
    echo "3/3 Starting subscription and wait till synchronization is complete"
    psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" -c "
        SELECT pglogical.wait_for_subscription_sync_complete('subscription$SUBSCRIPTION_ID');

        SELECT pglogical.show_subscription_status();"

    echo "Pglogical init done"
}

# This script will be executed during "docker-entrypoint.sh". When it either executes or sources all *.sh files in the /docker-entrypoint-initdb.d/ directory.

echo "host  replication  all  0.0.0.0/0  md5" >> $PGDATA/pg_hba.conf

init_this_subscriber &

