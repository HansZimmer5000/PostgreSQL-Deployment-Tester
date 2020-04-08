# General Info at: https://docs.docker.com/engine/reference/builder/#understand-how-arg-and-from-interact

# Declare (outside of build) so it can be used in FROM
ARG PG_NEW_MAJOR_VERSION
FROM postgres:$PG_NEW_MAJOR_VERSION

# Declare (inside of build) so it can be used further on
ARG PG_NEW_MAJOR_VERSION
ARG PG_OLD_MAJOR_VERSION

RUN echo $PG_NEW_MAJOR_VERSION
RUN echo $PG_OLD_MAJOR_VERSION

# Actual Dockerfile
RUN sed -i 's/$/ ${PG_OLD_MAJOR_VERSION}/' /etc/apt/sources.list.d/pgdg.list

RUN apt-get update && apt-get install -y --no-install-recommends \
		postgresql-${PG_OLD_MAJOR_VERSION} \
		postgresql-contrib-${PG_OLD_MAJOR_VERSION} \
	&& rm -rf /var/lib/apt/lists/*

ENV PGBINOLD /usr/lib/postgresql/${PG_OLD_MAJOR_VERSION}/bin
ENV PGBINNEW /usr/lib/postgresql/${PG_NEW_MAJOR_VERSION}/bin

ENV PGDATAOLD /var/lib/postgresql/${PG_OLD_MAJOR_VERSION}/data
ENV PGDATANEW /var/lib/postgresql/${PG_NEW_MAJOR_VERSION}/data

RUN mkdir -p "$PGDATAOLD" "$PGDATANEW" \
	&& chown -R postgres:postgres /var/lib/postgresql

WORKDIR /var/lib/postgresql

COPY docker-upgrade /usr/local/bin/

ENTRYPOINT ["docker-upgrade"]

# recommended: --link
CMD ["pg_upgrade"]
