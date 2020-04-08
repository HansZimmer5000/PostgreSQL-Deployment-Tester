FROM postgres:10.12

# Change to user root
USER 0

# Prepare OS
RUN apt-get update
RUN apt-get -y install curl
RUN apt-get -y install apt-utils
RUN apt-get -y install net-tools
RUN apt-get -y install ca-certificates gnupg lsb-release

RUN curl https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add -
RUN sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list'

# Does not work with "curl ... | bash"
RUN a=$(curl https://access.2ndquadrant.com/api/repository/dl/default/release/deb); bash -c "$a"
RUN apt-get install postgresql-10-pglogical

# Change to user postgres (see https://github.com/docker-library/postgres/blob/master/10/Dockerfile)
USER 999

EXPOSE 5432
