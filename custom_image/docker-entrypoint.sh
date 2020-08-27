#!/usr/bin/env bash
set -Eeo pipefail
# TODO swap to -Eeuo pipefail above (after handling all potentially-unset variables)

# usage: file_env VAR [DEFAULT]
#    ie: file_env 'XYZ_DB_PASSWORD' 'example'
# (will allow for "$XYZ_DB_PASSWORD_FILE" to fill in the value of
#  "$XYZ_DB_PASSWORD" from a file, especially for Docker's secrets feature)
file_env() {
        local var="$1"
        local fileVar="${var}_FILE"
        local def="${2:-}"
        if [ "${!var:-}" ] && [ "${!fileVar:-}" ]; then
                echo >&2 "error: both $var and $fileVar are set (but are exclusive)"
                exit 1
        fi
        local val="$def"
        if [ "${!var:-}" ]; then
                val="${!var}"
        elif [ "${!fileVar:-}" ]; then
                val="$(< "${!fileVar}")"
        fi
        export "$var"="$val"
        unset "$fileVar"
}

if [ "${1:0:1}" = '-' ]; then
        set -- postgres "$@"
fi

# allow the container to be started with `--user`
if [ "$1" = 'postgres' ] && [ "$(id -u)" = '0' ]; then
        echo "LINE 33 BEING EXECUTED"

        mkdir -p "$PGDATA"
        chown -R postgres "$PGDATA"
        chmod 700 "$PGDATA"

        mkdir -p /var/run/postgresql
        chown -R postgres /var/run/postgresql
        chmod 775 /var/run/postgresql

        # Create the transaction log directory before initdb is run (below) so the directory is owned by the correct user
        if [ "$POSTGRES_INITDB_XLOGDIR" ]; then
                mkdir -p "$POSTGRES_INITDB_XLOGDIR"
                chown -R postgres "$POSTGRES_INITDB_XLOGDIR"
                chmod 700 "$POSTGRES_INITDB_XLOGDIR"
        fi

        exec gosu postgres "$BASH_SOURCE" "$@"
fi


# Modification from the normal script to get the current state via pg_basebackup
# If given PROVIDER_IP is not empty.

# This is neccessary as it would otherwise fail if a replica would like to get pg_basebackup from itself.
# The normal flags will be set again after our modification.
set +Eeo pipefail

provider_is_reachable=false

if ! [ -z "$PROVIDER_IP" ] ; then
        echo "Try to reach $PROVIDER_IP:5432"
        curl -s $PROVIDER_IP:5432
        return_code=$?
        echo "Got Curl Exit Code $return_code"
        if [ "$return_code" == "52" ] || [ "$return_code" == "0" ] ; then
                # 52 = Empty Reply from Server means its up, otherwise there is no answer at all (Connect refused)
                provider_is_reachable=true
                echo "Provider is reachable."
        else
                echo "Error: Provider is not reachable. Curl exit code: $return_code"
        fi
fi

# $1 = Bool, Provider is Reachable
# $2 = Text, Provider IP
init_basebackup(){
    echo "*:*:*:$POSTGRES_USER:$POSTGRES_PASSWORD" > ~/.pgpass
    chmod 0600 ~/.pgpass

    echo "-- executing pg_basebackup"
    pg_basebackup -c fast -X stream -h $1 -U postgres -v --no-password -D $2 
}

upgrade_backup(){
    echo "-- executing pg_upgrade"
    export PGBINOLD=/usr/lib/postgresql/9.5/bin
    export PGBINNEW=/usr/lib/postgresql/10/bin
    export PGDATAOLD=$1
    export PGDATANEW=$2


    #$PGBINOLD/pg_controldata -D $PGDATAOLD 
    #$PGBINOLD/pg_ctl -D $PGDATAOLD reload
    #$PGBINOLD/pg_ctl -D $PGDATAOLD stop -t 5
    #ls -a $PGDATAOLD
    #cat $PGDATAOLD/postmaster.pid
    #mv $PGDATAOLD/postmaster.pid $PGDATAOLD/old_postmaster.old 

    # Change current location to be able to write in the folder (log)
    orig_dir=$(pwd)
    cd ~
    if [ -d $PGBINNEW ]; then 
        $PGBINNEW/pg_upgrade 
    fi
    cd $orig_dir
}

backup_dir="/var/lib/postgresql/9.5/data"
if ! [ -z "$PGDATA_OLD" ]; then
        backup_dir="$PGDATA_OLD"
fi

# TODO code clearer that there are two ways. 
# 1 = PGDATA_OLD is not set -> get data from provider via pg_basebackup, use normal backup_dir, then upgrade it
# 2 = PGDATA_OLD is set -> use PGDATA_OLD as backup_dir and upgrade data.

# Get Backup only if Provider is reachable and a mount was not reused
if "$provider_is_reachable" && [ -z "$PGDATA_OLD" ]; then
    init_basebackup $PROVIDER_IP $backup_dir
fi

init_new_db=true
if [ "$(ls -A $PGDATA)" ]; then
        init_new_db=false
fi

set -Eeo pipefail
# Modification End

if [ "$1" = 'postgres' ]; then
        mkdir -p "$PGDATA"
        chown -R "$(id -u)" "$PGDATA" 2>/dev/null || :
        chmod 700 "$PGDATA" 2>/dev/null || :

        # look specifically for PG_VERSION, as it is expected in the DB dir
        if [ ! -s "$PGDATA/PG_VERSION" ] && $init_new_db; then
                # "initdb" is particular about the current user existing in "/etc/passwd", so we use "nss_wrapper" to fake that if necessary
                # see https://github.com/docker-library/postgres/pull/253, https://github.com/docker-library/postgres/issues/359, https://cwrap.org/nss_wrapper.html
                if ! getent passwd "$(id -u)" &> /dev/null && [ -e /usr/lib/libnss_wrapper.so ]; then
                        export LD_PRELOAD='/usr/lib/libnss_wrapper.so'
                        export NSS_WRAPPER_PASSWD="$(mktemp)"
                        export NSS_WRAPPER_GROUP="$(mktemp)"
                        echo "postgres:x:$(id -u):$(id -g):PostgreSQL:$PGDATA:/bin/false" > "$NSS_WRAPPER_PASSWD"
                        echo "postgres:x:$(id -g):" > "$NSS_WRAPPER_GROUP"
                fi
                
                file_env 'POSTGRES_USER' 'postgres'
                file_env 'POSTGRES_PASSWORD'

                file_env 'POSTGRES_INITDB_ARGS'
                if [ "$POSTGRES_INITDB_XLOGDIR" ]; then
                        export POSTGRES_INITDB_ARGS="$POSTGRES_INITDB_ARGS --xlogdir $POSTGRES_INITDB_XLOGDIR"
                fi
                eval 'initdb --username="$POSTGRES_USER" --pwfile=<(echo "$POSTGRES_PASSWORD") '"$POSTGRES_INITDB_ARGS"

                # Modification
                # Upgrade if provider is reachable (which implies execution of pg_basebackup) or PGDATA_OLD is set.
                set +Eeo pipefail
                data_from_upgrade=false
                if "$provider_is_reachable" || ! [ -z "$PGDATA_OLD" ]; then
                    upgrade_backup $backup_dir $PGDATA
                    data_from_upgrade=true
                    init_new_db=false
                fi
                set -Eeo pipefail
                # Modification End
                
                # unset/cleanup "nss_wrapper" bits
                if [ "${LD_PRELOAD:-}" = '/usr/lib/libnss_wrapper.so' ]; then
                        rm -f "$NSS_WRAPPER_PASSWD" "$NSS_WRAPPER_GROUP"
                        unset LD_PRELOAD NSS_WRAPPER_PASSWD NSS_WRAPPER_GROUP
                fi

                # check password first so we can output the warning before postgres
                # messes it up
                if [ -n "$POSTGRES_PASSWORD" ]; then
                        authMethod=md5

                        if [ "${#POSTGRES_PASSWORD}" -ge 100 ]; then
                                cat >&2 <<-'EOWARN'

                                        WARNING: The supplied POSTGRES_PASSWORD is 100+ characters.
                                         
                                         This will not work if used via PGPASSWORD with "psql".
                                          
                                          https://www.postgresql.org/message-id/flat/E1Rqxp2-0004Qt-PL%40wrigleys.postgresql.org (BUG #6412)
                                          https://github.com/docker-library/postgres/issues/507

EOWARN
                        fi
                else
                        # The - option suppresses leading tabs but *not* spaces. :)
                        cat >&2 <<-'EOWARN'
                                ****************************************************
                                WARNING: No password has been set for the database.
                                         This will allow anyone with access to the
                                         Postgres port to access your database. In
                                         Docker's default configuration, this is
                                         effectively any other container on the same
                                         system.
                                         
                                         Use "-e POSTGRES_PASSWORD=password" to set
                                         it in "docker run".
                                ****************************************************
EOWARN

                        authMethod=trust
                fi

                {
                        echo "host all all all $authMethod"
                } >> "$PGDATA/pg_hba.conf"

                # internal start of server in order to allow set-up using psql-client
                # does not listen on external TCP/IP and waits until start finishes
                PGUSER="${PGUSER:-$POSTGRES_USER}" \
                pg_ctl -D "$PGDATA" \
                        -o "-c listen_addresses=''" \
                        -w start

                file_env 'POSTGRES_DB' "$POSTGRES_USER"

                export PGPASSWORD="${PGPASSWORD:-$POSTGRES_PASSWORD}"
                psql=( psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --no-password )

                if [ "$POSTGRES_DB" != 'postgres' ] && ! $data_from_upgrade; then # Modification: && ! $data_from_upgrade 
                        "${psql[@]}" --dbname postgres --set db="$POSTGRES_DB" <<-'EOSQL'
                                CREATE DATABASE :"db" ;
EOSQL
                        echo
                fi
                psql+=( --dbname "$POSTGRES_DB" )

                echo
                ls /docker-entrypoint-initdb.d/
                for f in /docker-entrypoint-initdb.d/*; do
                        case "$f" in
                                *.sh)
                                        # https://github.com/docker-library/postgres/issues/450#issuecomment-393167936
                                        # https://github.com/docker-library/postgres/pull/452
                                        if [ -x "$f" ]; then
                                                echo "$0: running $f"
                                                "$f"
                                        else
                                                echo "$0: sourcing $f"
                                                . "$f"
                                        fi
                                        ;;
                                *.sql)    echo "$0: running $f"; "${psql[@]}" -f "$f"; echo ;;
                                *.sql.gz) echo "$0: running $f"; gunzip -c "$f" | "${psql[@]}"; echo ;;
                                *)        echo "$0: ignoring $f" ;;
                        esac
                        echo
                done

                PGUSER="${PGUSER:-$POSTGRES_USER}" \
                pg_ctl -D "$PGDATA" -m fast -w stop

                unset PGPASSWORD

                echo
                echo 'PostgreSQL init process complete; ready for start up.'
                echo

                # Modification
                echo "host  replication  all  0.0.0.0/0  md5" >> $PGDATA/pg_hba.conf
                # End of Modification
        fi
fi

# Modification
set +Eeo pipefail

/etc/sub_setup.sh $provider_is_reachable $PROVIDER_IP $init_new_db

set -Eeo pipefail
# End of Modification

exec "$@"