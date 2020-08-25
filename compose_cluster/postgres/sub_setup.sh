#!/bin/bash

wait_for_startup() {
    echo "Waiting for this subscriber to startup, sleeping 1s each:"
    sleep 10s
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
    #TODO Used interface may change when network is changed!!
    IPs=($(ifconfig eth0 | grep "inet"))
    echo ${IPs[1]}
}

# $1 = Bool, Provider is Reachable
# $2 = Text, Provider IP
# $3 = Bool, Database exists
init_replication() {
    wait_for_startup 
    SUBSCRIBER_IP=$(get_ip)
    SUBSCRIPTION_ID="${SUBSCRIBER_IP//./}"

    if $3; then # TODO echo empty $3 is true
            echo "Setup Replication from Scratch"
            psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" -c "
            -- PG LOGICAL
            CREATE EXTENSION pglogical;
            "
    else
            echo "Setup Replication by demoting"
            psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" -c "
            -- PG LOGICAL
            DROP EXTENSION pglogical;
            CREATE EXTENSION pglogical;
            "
    fi

    echo "Using IP ($SUBSCRIBER_IP) and ID ($SUBSCRIPTION_ID)"

    echo "1/3 Creating local pglogical node"
    psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" -c "
        SELECT pglogical.create_node(
            node_name := 'subscriber95',
            dsn := 'host=$SUBSCRIBER_IP port=5432 dbname=$POSTGRES_DB password=$POSTGRES_PASSWORD user=$POSTGRES_USER'
        );"

    if $1; then
        echo "2/3 Creating subscription"
        psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" -c "
            -- user Docker Service Name as host url
            SELECT pglogical.create_subscription(
                subscription_name := 'subscription$SUBSCRIPTION_ID',
                provider_dsn := 'host=$2 port=5432 dbname=$POSTGRES_DB password=$POSTGRES_PASSWORD user=$POSTGRES_USER'
            );"
            
        echo "3/3 Starting subscription and wait till synchronization is complete"
        psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" -c "
            SELECT pglogical.wait_for_subscription_sync_complete('subscription$SUBSCRIPTION_ID');

            SELECT pglogical.show_subscription_status();"
    else
        echo "Provider is not reachable, Skipping Step 2/3 and 3/3."
    fi

    echo "Pglogical init done"
}

# This script will be executed at the end of "docker-entrypoint.sh". 
# $1 = Provider is reachable
# $2 = Provider IP
# $3 = init new Database
echo "Setting up Replica from Scratch ($3) with Reachable Provider ($1) and its (V)IP ($2)"

init_replication $1 $2 $3 &
