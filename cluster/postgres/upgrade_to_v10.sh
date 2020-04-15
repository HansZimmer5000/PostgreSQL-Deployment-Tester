#!/bin/sh

# Install new Major Version
echo "deb http://apt.postgresql.org/pub/repos/apt/ stretch-pgdg main 10" > /etc/apt/sources.list.d/pgdg.list
apt-get update
apt-get install -y --no-install-recommends --no-install-suggests postgresql-10
#rm -rf /var/lib/apt/lists/* #There was nothing there. Why is this line here then?

# Upgrade 
su - postgres -c "
export PGBINOLD=/usr/lib/postgresql/9.5/bin
export PGBINNEW=/usr/lib/postgresql/10/bin

export PGDATAOLD=/var/lib/postgresql/9.5/data
export PGDATANEW=/var/lib/postgresql/10/data

mkdir -p "$PGDATAOLD" "$PGDATANEW"
chown -R postgres:postgres /var/lib/postgresql

PGDATA=/var/lib/postgresql/9.5/data /usr/lib/postgresql/9.5/bin/pg_ctl stop
PGDATA=/var/lib/postgresql/10/data /usr/lib/postgresql/10/bin/pg_ctl init
/usr/lib/postgresql/10/bin/pg_upgrade
"

# Start new Postgres
su - postgres -c "
PGDATA=/var/lib/postgresql/10/data /usr/lib/postgresql/10/bin/pg_ctl start
"