#!/bin/sh

echo "-- Install new Major Version"
echo "deb http://apt.postgresql.org/pub/repos/apt/ stretch-pgdg main 10" > /etc/apt/sources.list.d/pgdg.list
apt-get update 1>/dev/null
apt-get install -y --no-install-recommends --no-install-suggests postgresql-10 1>/dev/null

echo "-- Upgrade"
su - postgres -c "
export PGBINOLD=/usr/lib/postgresql/9.5/bin
export PGBINNEW=/usr/lib/postgresql/10/bin

export PGDATAOLD=/var/lib/postgresql/9.5/data
export PGDATANEW=/var/lib/postgresql/10/data

mkdir -p /var/lib/postgresql/9.5/data /var/lib/postgresql/10/data
chown -R postgres:postgres /var/lib/postgresql

PGDATA=/var/lib/postgresql/9.5/data /usr/lib/postgresql/9.5/bin/pg_ctl stop
PGDATA=/var/lib/postgresql/10/data /usr/lib/postgresql/10/bin/pg_ctl init

/usr/lib/postgresql/10/bin/pg_upgrade
"

echo "-- Start new Postgres"
su - postgres -c "
PGDATA=/var/lib/postgresql/10/data /usr/lib/postgresql/10/bin/pg_ctl start
"