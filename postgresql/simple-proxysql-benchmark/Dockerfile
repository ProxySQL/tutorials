FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && \
    apt-get install -y \
    sysbench \
    postgresql-client \
    curl \
    supervisor \
    && apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Install ProxySQL from release deb package
ARG TARGETARCH

RUN curl -fSL "https://github.com/sysown/proxysql/releases/download/v4.0.6/proxysql_4.0.6-ubuntu22_${TARGETARCH}.deb" \
    -o /tmp/proxysql.deb

RUN apt-get update && \
    apt-get install -y --no-install-recommends /tmp/proxysql.deb && \
    rm -f /tmp/proxysql.deb && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Create ProxySQL data directory
RUN mkdir -p /var/lib/proxysql && \
    chown -R proxysql:proxysql /var/lib/proxysql

# Configure supervisor to run ProxySQL
COPY cnf/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
