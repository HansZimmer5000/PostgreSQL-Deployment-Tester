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

get_ip() {
    #IPs=($(hostname -I)) # Konvertiert Leerzeichen getrennten Text direkt zu Array, TODO Überall einführen wo sinnvoll & leerzeichen Listen genutzt!
    IPs=($(ifconfig eth1 | grep "inet"))
    echo ${IPs[1]}
}

init_this_subscriber() {
    wait_for_primary
    wait_for_startup 
    SUBSCRIBER_IP=$(get_ip)
    SUBSCRIPTION_ID="${SUBSCRIBER_IP//./}"

    echo "Using IP ($SUBSCRIBER_IP) and ID ($SUBSCRIPTION_ID)"

    set -e

    echo "host  replication  all  0.0.0.0/0  md5" >> /var/lib/postgresql/data/pg_hba.conf

    psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" -c "
        -- PG LOGICAL
        CREATE EXTENSION pglogical;

        SELECT pglogical.create_node(
            node_name := 'subscriber95',
            dsn := 'host=$SUBSCRIBER_IP port=5432 dbname=testdb password=pass user=primaryuser'
        );"
    echo "First third done"

    psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" -c "
        -- user Docker Service Name as host url
        SELECT pglogical.create_subscription(
            subscription_name := 'subscription$SUBSCRIPTION_ID',
            provider_dsn := 'host=192.168.1.149 port=5433 dbname=testdb password=pass user=primaryuser'
        );"
    echo "Second third done"

    psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" -c "
        SELECT pglogical.wait_for_subscription_sync_complete('subscription$SUBSCRIPTION_ID');

        SELECT pglogical.show_subscription_status();"
    echo "Init Sub Done"
}

echo "host  replication  all  0.0.0.0/0  md5" >> /var/lib/postgresql/data/pg_hba.conf

init_this_subscriber &
