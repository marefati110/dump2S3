# Postgres version passed as build ARG
ARG POSTGRES_VERSION
FROM postgres:${POSTGRES_VERSION}-alpine

ARG TARGETARCH
ENV TARGETARCH=${TARGETARCH}

# Copy scripts into container
COPY src/install.sh /install.sh
COPY src/run.sh /run.sh
COPY src/env.sh /env.sh
COPY src/backup.sh /backup.sh

RUN sh /install.sh && rm /install.sh \
    && chmod +x /run.sh /env.sh /backup.sh

# Environment variables with defaults
ENV POSTGRES_HOST=localhost \
    POSTGRES_PORT=5432 \
    POSTGRES_USER=postgres \
    POSTGRES_PASSWORD=postgres \
    PGDUMP_EXTRA_OPTS="" \
    \
    S3_ACCESS_KEY_ID="" \
    S3_SECRET_ACCESS_KEY="" \
    S3_BUCKET="" \
    S3_REGION="us-west-1" \
    S3_PATH="backup" \
    S3_ENDPOINT="" \
    S3_S3V4="no" \
    \
    SCHEDULE="" \
    BACKUP_KEEP_DAYS="" \
    GZIP_ENABLED="yes" \
    RUN_BACKUP_ON_START="false" \
    WEBHOOK_URL=""


# Default command
CMD ["sh", "/run.sh"]
