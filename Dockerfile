FROM alpine:latest

RUN apk update && \
    apk add --no-cache \
    bash \
    s3cmd \
    curl \
    zip \
    tar \
    gzip \
    xz

RUN curl -o /tmp/mc https://dl.min.io/client/mc/release/linux-amd64/mc && \
    chmod +x /tmp/mc && \
    mv /tmp/mc /usr/local/bin/mc

RUN mc --version

COPY backup.sh /usr/local/bin/backup.sh

RUN adduser -D -s /bin/bash backupuser
RUN chmod +x /usr/local/bin/backup.sh && \
    chown backupuser:backupuser /usr/local/bin/backup.sh

USER backupuser

CMD ["/usr/local/bin/backup.sh"]