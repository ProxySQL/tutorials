FROM arm64v8/ubuntu:22.04

RUN apt-get update && \
    apt-get install -y sysbench postgresql-client && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

COPY benchmark.sh /usr/local/bin/benchmark.sh
RUN chmod +x /usr/local/bin/benchmark.sh

CMD ["tail", "-f", "/dev/null"]
