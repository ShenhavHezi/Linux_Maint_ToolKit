FROM debian:bookworm

RUN apt-get update && apt-get install -y \
    bash \
    ca-certificates \
    coreutils \
    curl \
    findutils \
    gawk \
    grep \
    iputils-ping \
    jq \
    openssh-client \
    openssl \
    procps \
    python3 \
    sed \
    shellcheck \
    sudo \
    tar \
    util-linux \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /work
