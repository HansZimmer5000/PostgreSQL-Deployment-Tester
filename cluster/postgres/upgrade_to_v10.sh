#!/bin/bash

echo "-- Install new Major Version"
# TODO Some of the installed packages needs READLINE, I guess to select wheter version to install.

echo "deb http://apt.postgresql.org/pub/repos/apt/ stretch-pgdg main 10" > /etc/apt/sources.list.d/pgdg.list
apt-get update 1>/dev/null
apt-get install -y --no-install-recommends --no-install-suggests postgresql-10 postgresql-10-pglogical 1>/dev/null

echo "-- Upgrade"
# TODO postgres exists in Container, but not in Database (Role). Either set postgres or change all to postgres user.
mkdir -p /var/lib/postgresql/9.5/data /var/lib/postgresql/10/data
chown -R postgres:postgres /var/lib/postgresql

su - postgres -c "
export PGBINOLD=/usr/lib/postgresql/9.5/bin
export PGBINNEW=/usr/lib/postgresql/10/bin
export PGDATAOLD=/var/lib/postgresql/9.5/data
export PGDATANEW=/var/lib/postgresql/10/data

PGDATA=/var/lib/postgresql/9.5/data /usr/lib/postgresql/9.5/bin/pg_ctl stop 
PGDATA=/var/lib/postgresql/10/data /usr/lib/postgresql/10/bin/initdb -E 'UTF-8' --locale=en_US.utf8

# Reuse old configuratoin file
cp /var/lib/postgresql/9.5/data/postgresql.conf /var/lib/postgresql/10/data/postgresql.conf
cp /var/lib/postgresql/9.5/data/pg_hba.conf /var/lib/postgresql/10/data/pg_hba.conf

/usr/lib/postgresql/10/bin/pg_upgrade
"

echo "-- Setup Postgres (PGLogical)"

get_ip() {
    #IPs=($(hostname -I)) # Konvertiert Leerzeichen getrennten Text direkt zu Array, TODO Überall einführen wo sinnvoll & leerzeichen Listen genutzt!
    IPs=($(ifconfig eth1 | grep "inet"))
    echo ${IPs[1]}
}

reconnect() {
    echo "Next line may fail if database was not able to start right in the first place"

    psql -e -v ON_ERROR_STOP=1 --username postgres --dbname testdb -c "SELECT pglogical.drop_subscription('$1');"

    psql -e -v ON_ERROR_STOP=1 --username postgres --dbname testdb -c "SELECT pglogical.create_subscription(subscription_name := '$1',provider_dsn := 'host=192.168.1.149 port=5433 dbname=testdb password=pass user=postgres');"

    psql -e -v ON_ERROR_STOP=1 --username postgres --dbname testdb -c "SELECT pglogical.wait_for_subscription_sync_complete('$1');"

    psql -e -v ON_ERROR_STOP=1 --username postgres --dbname testdb -c "SELECT pglogical.show_subscription_status('$1');"

}

PGDATA=/var/lib/postgresql/10/data
echo "Current PGDATA: $PGDATA"
echo "host  replication  all  0.0.0.0/0  md5" >> $PGDATA/pg_hba.conf

echo "-- Start new Postgres"
su - postgres -c "
PGDATA=/var/lib/postgresql/10/data /usr/lib/postgresql/10/bin/pg_ctl start
"

#init_this_subscriber
SUBSCRIBER_IP=$(get_ip)
SUBSCRIPTION_ID="${SUBSCRIBER_IP//./}"
reconnect "subscription$SUBSCRIPTION_ID"
