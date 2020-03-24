#!/bin/bash

#ls -a /etc/
#ls -a /etc/postgresql 
#cat /etc/postgresql/postgresql.conf

set -e

echo "host  replication  all  0.0.0.0/0  md5" >> /var/lib/postgresql/data/pg_hba.conf

show_status() {
    sleep 20s
    psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL1
        SELECT pglogical.show_subscription_status();
EOSQL1
}

init_provider() {
    psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
        -- PG LOGICAL

        CREATE EXTENSION pglogical;

        SELECT pglogical.create_node(
            node_name := 'provider95',
            dsn := 'host=provider port=5432 dbname=testdb password=pass user=primaryuser'
        );

        SELECT pglogical.replication_set_add_all_tables('default', ARRAY['public']);

        SELECT pglogical.show_subscription_status();
EOSQL
}

init_provider

show_status &
