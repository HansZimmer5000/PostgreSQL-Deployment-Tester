#!/bin/sh

echo "-- Install new Major Version"
# TODO Some of the installed packages needs READLINE, I guess to select wheter version to install.

echo "deb http://apt.postgresql.org/pub/repos/apt/ stretch-pgdg main 10" > /etc/apt/sources.list.d/pgdg.list
apt-get update 1>/dev/null
apt-get install -y --no-install-recommends --no-install-suggests postgresql-10 1>/dev/null

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
#TODO install pglogical in v10, reuse configuration from older version and setup pglogical again as before (via sub_setup. Does this need updating to fit to v10?)
/usr/lib/postgresql/10/bin/pg_upgrade
"

echo "-- Start new Postgres"
su - postgres -c "
PGDATA=/var/lib/postgresql/10/data /usr/lib/postgresql/10/bin/pg_ctl start
" 