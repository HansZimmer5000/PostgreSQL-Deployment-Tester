FROM postgres:9.5.18

# Change to user root
USER 0

# Prepare OS
RUN apt-get update
RUN apt-get -y install curl
RUN apt-get -y install apt-utils
RUN apt-get -y install net-tools

RUN apt-get -y install curl ca-certificates gnupg
RUN curl https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add -
RUN sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list'

# Does not work with "curl ... | bash"
RUN a=$(curl https://access.2ndquadrant.com/api/repository/dl/default/release/deb); bash -c "$a"
RUN apt-get install postgresql-9.5-pglogical

# Give Postgres permission to use the volume
RUN mkdir -p /var/lib/postgresql/9.5/data
RUN chown -R postgres /var/lib/postgresql/9.5/data
VOLUME [ "/var/lib/postgresql/9.5/data" ]
ENV PGDATA="/var/lib/postgresql/9.5/data"

# Change to user postgres (see https://github.com/docker-library/postgres/blob/master/9.5/Dockerfile)
USER 999

EXPOSE 5432
COPY entrypoint.sh /entrypoint.sh

ENTRYPOINT [ "/entrypoint.sh" ]