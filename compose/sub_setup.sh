#!/bin/bash
wait_till_reachable() {
    refused=true
    while $refused; do
        sleep 1
        echo "Try to reach $1"

        echo $(curl -s $1) >> /dev/null

        if [ "$?" != "0" ]; then
            refused=true
            echo "Not Successfull: $?"
        else
            refused=false
        fi
    done
    echo "Success"
}

wait_for_primary() {
    wait_till_reachable provider

    echo "Waiting for provider to finalize setup, sleeping 5s"
    sleep 5s
}

wait_for_startup() {
    echo "Waiting for this subscriber to startup, sleeping 10s"
    sleep 10s
}

init_this_subscriber() {
    wait_for_primary
    wait_for_startup 

    set -e

    echo "host  replication  all  0.0.0.0/0  md5" >> /var/lib/postgresql/data/pg_hba.conf

    psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
        -- PG LOGICAL
        CREATE EXTENSION pglogical;

        SELECT pglogical.create_node(
            node_name := 'subscriber95',
            dsn := 'host=subscriber port=5432 dbname=testdb password=pass user=primaryuser'
        );

        -- user Docker Service Name as host url
        SELECT pglogical.create_subscription(
            subscription_name := 'subscription1',
            provider_dsn := 'host=provider port=5432 dbname=testdb password=pass user=primaryuser'
        );

        SELECT pglogical.wait_for_subscription_sync_complete('subscription1');

        SELECT pglogical.show_subscription_status();
EOSQL
    echo "Init Sub Done"
}

init_this_subscriber &

