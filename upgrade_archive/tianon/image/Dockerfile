FROM postgres:10

RUN sed -i 's/$/ 9.5/' /etc/apt/sources.list.d/pgdg.list

RUN apt-get update && apt-get install -y --no-install-recommends postgresql-9.5=9.5.23-1.pgdg90+1 postgresql-contrib-9.5=9.5.23-1.pgdg90+1 curl apt-utils net-tools lsb-core ca-certificates gnupg
RUN curl https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add -
RUN sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list'

# Does not work with "curl ... | bash"
RUN a=$(curl https://access.2ndquadrant.com/api/repository/dl/default/release/deb); bash -c "$a"
RUN apt-get install postgresql-9.5-pglogical
RUN curl https://access.2ndquadrant.com/api/repository/dl/default/release/deb | bash
RUN apt-get install postgresql-10-pglogical


RUN rm -rf /var/lib/apt/lists/*



ENV PGBINOLD /usr/lib/postgresql/9.5/bin
ENV PGBINNEW /usr/lib/postgresql/10/bin

ENV PGDATAOLD /var/lib/postgresql/9.5/data
ENV PGDATANEW /var/lib/postgresql/10/data

RUN mkdir -p "$PGDATAOLD" "$PGDATANEW" \
	&& chown -R postgres:postgres /var/lib/postgresql

WORKDIR /var/lib/postgresql

COPY docker-upgrade /usr/local/bin/

ENTRYPOINT ["docker-upgrade"]

# recommended: --link
CMD ["pg_upgrade"]