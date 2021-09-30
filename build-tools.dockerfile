FROM ubuntu:20.04 as base
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get upgrade -y && \
    apt-get install openssl libssl-dev libpq-dev libpqxx-dev build-essential cmake libboost-all-dev git \
    autoconf2.13 libgmp-dev curl libcurl4-openssl-dev python3-pkgconfig ninja-build gdb -y && \
    rm -rf /var/cache/apt/lists
