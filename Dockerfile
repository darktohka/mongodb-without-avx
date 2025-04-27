FROM debian:12-slim as build

RUN apt update -y && apt install -y build-essential \
        libcurl4-openssl-dev \
        liblzma-dev \
        libssl-dev \
        python-dev-is-python3 \
        python3-pip \
        curl \
    && rm -rf /var/lib/apt/lists/*

ARG MONGO_VERSION=8.0.8

RUN mkdir /src && \
    curl -o /tmp/mongo.tar.gz -L "https://github.com/mongodb/mongo/archive/refs/tags/r${MONGO_VERSION}.tar.gz" && \
    tar xaf /tmp/mongo.tar.gz --strip-components=1 -C /src && \
    rm /tmp/mongo.tar.gz

WORKDIR /src

COPY ./o2_patch.diff /o2_patch.diff
RUN patch -p1 < /o2_patch.diff

RUN export GIT_PYTHON_REFRESH=quiet && \
    python3 -m pip install --break-system-packages poetry && \
    python3 -m poetry install --sync --no-root && \
    python3 buildscripts/scons.py install-servers MONGO_VERSION="${MONGO_VERSION}" --release --disable-warnings-as-errors -j $(nproc) && \
    mv build/install /install && \
    strip --strip-debug /install/bin/mongod && \
    strip --strip-debug /install/bin/mongos && \
    rm -rf build

FROM debian:12-slim

RUN apt update -y && \
    apt install -y libcurl4 && \
    apt-get clean \
    && rm -rf /var/lib/apt/lists/*

COPY --from=build /install/bin/mongo* /usr/local/bin/

RUN mkdir -p /data/db && \
    chmod -R 750 /data && \
    chown -R 999:999 /data

USER 999

ENTRYPOINT [ "/usr/local/bin/mongod" ]
