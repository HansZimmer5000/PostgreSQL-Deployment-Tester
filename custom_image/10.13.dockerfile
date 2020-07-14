FROM postgres:10.13

# Change to user root
USER 0

# Prepare OS
RUN apt-get update
RUN apt-get -y install curl apt-utils net-tools lsb-core

RUN apt-get -y install curl ca-certificates gnupg
RUN curl https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add -
RUN sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list'

# Does not work with "curl ... | bash"
#v1 RUN a=$(curl https://access.2ndquadrant.com/api/repository/dl/default/release/deb); bash -c "$a"
RUN curl https://access.2ndquadrant.com/api/repository/dl/default/release/deb | bash
RUN apt-get install postgresql-10-pglogical

# Needed for pg_upgrade during startup (after receiving data via pg_basebackup)
#RUN "deb http://apt.postgresql.org/pub/repos/apt/ $(lsb_release -cs)-pgdg main 10" > /etc/apt/sources.list.d/pgdg.list
RUN apt-get install -y --no-install-recommends --no-install-suggests postgresql-9.5 

# Give Postgres permission to use the volume
RUN mkdir -p /var/lib/postgresql/10/data
RUN chown -R postgres /var/lib/postgresql/10/data
VOLUME [ "/var/lib/postgresql/10/data" ]
ENV PGDATA="/var/lib/postgresql/10/data"

# Change to user postgres (see https://github.com/docker-library/postgres/blob/master/9.5/Dockerfile)
USER 999
COPY docker-entrypoint.sh /docker-entrypoint.sh
EXPOSE 5432

ENTRYPOINT [ "docker-entrypoint.sh" ]
CMD [ "postgres" ]