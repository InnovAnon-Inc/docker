FROM nvidia/cuda:11.1-devel-ubuntu16.04 as base

MAINTAINER Innovations Anonymous <InnovAnon-Inc@protonmail.com>
LABEL version="1.0"                                                     \
      maintainer="Innovations Anonymous <InnovAnon-Inc@protonmail.com>" \
      about="Dockerized Crypto Miner"                                   \
      org.label-schema.build-date=$BUILD_DATE                           \
      org.label-schema.license="PDL (Public Domain License)"            \
      org.label-schema.name="Dockerized Crypto Miner"                   \
      org.label-schema.url="InnovAnon-Inc.github.io/docker"             \
      org.label-schema.vcs-ref=$VCS_REF                                 \
      org.label-schema.vcs-type="Git"                                   \
      org.label-schema.vcs-url="https://github.com/InnovAnon-Inc/docker"

# disable interactivity
ARG  DEBIAN_FRONTEND=noninteractive
ENV  DEBIAN_FRONTEND ${DEBIAN_FRONTEND}

# localization
ARG  TZ=UTC
ENV  TZ ${TZ}
ARG  LANG=C.UTF-8
ENV  LANG ${LANG}
ARG  LC_ALL=C.UTF-8
ENV  LC_ALL ${LC_ALL}

# update/upgrade
RUN apt update \
 && apt full-upgrade -y

FROM base as builder

# build-deps
RUN apt install      -y git build-essential autoconf automake        \
                        libgmp-dev libmpc-dev libmpfr-dev libisl-dev \
                                  libhwloc-dev libssl-dev            \
                        cmake ninja
#  libcurl4-openssl-dev libjansson-dev
#  zlib1g-dev
#RUN apt install      -y lib32z1-dev
RUN apt install -y nvidia-cuda-toolkit




FROM builder as libuv

ARG CONF
ENV CONF ${CONF}

ARG CFLAGS
ARG CXXFLAGS
ENV CFLAGS ${CFLAGS}
ENV CXXFLAGS ${CXXFLAGS}

ARG DOCKER_TAG=sandybridge
ENV DOCKER_TAG ${DOCKER_TAG}

RUN git clone --depth=1 --recursive  \
    git://github.com/libuv/libuv.git \
    /app                             \
 && chown -R nobody:nogroup /app
WORKDIR                     /app
USER nobody
RUN mkdir -v build                                                      \
 && cd       build                                                      \
 && CXXFLAGS="$CXXFLAGS $CFLAGS -march=$DOCKER_TAG -mtune=$DOCKER_TAG"  \
                CFLAGS="$CFLAGS -march=$DOCKER_TAG -mtune=$DOCKER_TAG"  \
    cmake .. $CONF                                                      \
 && cd       ..                                                         \
 && cmake --build build
# how to install ?
# && sh autogen.sh                                                       \
# && ./configure                                                         \
#    CXXFLAGS="$CXXFLAGS $CFLAGS -march=$DOCKER_TAG -mtune=$DOCKER_TAG"  \
#                CFLAGS="$CFLAGS -march=$DOCKER_TAG -mtune=$DOCKER_TAG"  \
# && make                                                                \
# && make check                                                          \
RUN cd /app/build             \
 && make DESTDIR=dest install \
 && cd           dest         \
 && tar vpacf ../dest.txz --owner root --group root .


FROM builder as app

ARG CONF
ENV CONF ${CONF}

ARG CFLAGS
ARG CXXFLAGS
ENV CFLAGS ${CFLAGS}
ENV CXXFLAGS ${CXXFLAGS}

ARG DOCKER_TAG=sandybridge
ENV DOCKER_TAG ${DOCKER_TAG}

COPY --chown=root --from=libuv /app/build/dest.txz /dest.txz
RUN tar vxf /dest.txz -C / \
 && rm -v /dest.txz
RUN ls -ltra /usr/local/lib

RUN git clone --depth=1 --recursive  \
    git://github.com/xmrig/xmrig.git \
    /app                             \
 && chown -R nobody:nogroup /app
WORKDIR                     /app
USER nobody
RUN mkdir -v build                                                      \
 && cd       build                                                      \
 && CXXFLAGS="$CXXFLAGS $CFLAGS -march=$DOCKER_TAG -mtune=$DOCKER_TAG"  \
                CFLAGS="$CFLAGS -march=$DOCKER_TAG -mtune=$DOCKER_TAG"  \
    cmake .. $CONF                                                              \
      -DWITH_HWLOC=ON -DWITH_LIBCPUID=OFF                               \
      -DWITH_HTTP=OFF -DWITH_TLS=ON                                     \
      -DWITH_ASM=ON -DWITH_OPENCL=OFF -DWITH_CUDA=ON -DWITH_NVML=ON     \
      -DWITH_DEBUG_LOG=OFF -DHWLOC_DEBUG=OFF -DCMAKE_BUILD_TYPE=Release \
      -DWITH_CN_LITE=OFF -DWITH_CN_HEAVY=OFF -DWITH_CN_PICO=OFF -DWITH_ARGON2=OFF -DWITH_ASTROBWT=OFF -DWITH_KAWPOW=OFF \
 && make -j`nproc`                                                      \
 && strip --strip-all xmrig
#RUN upx --all-filters --ultra-brute cpuminer



FROM builder as lib

# build-deps
RUN apt install      -y git build-essential autoconf automake        \
                        libgmp-dev libmpc-dev libmpfr-dev libisl-dev \
                                  libhwloc-dev libssl-dev            \
                        cmake
#  libcurl4-openssl-dev libjansson-dev
#  zlib1g-dev
#RUN apt install      -y lib32z1-dev

ARG CONF
ENV CONF ${CONF}

ARG CFLAGS
ARG CXXFLAGS
ENV CFLAGS ${CFLAGS}
ENV CXXFLAGS ${CXXFLAGS}

ARG DOCKER_TAG=sandybridge
ENV DOCKER_TAG ${DOCKER_TAG}

COPY --chown=root --from=libuv /app/build/dest.txz /dest.txz
RUN tar vxf /dest.txz -C / \
 && rm -v /dest.txz

# repo
RUN git clone --depth=1 --recursive       \
    git://github.com/xmrig/xmrig-cuda.git \
    /app                                  \
 && chown -R nobody:nogroup /app
WORKDIR                     /app
USER nobody
RUN mkdir -v build                                                      \
 && cd       build                                                      \
 && CXXFLAGS="$CXXFLAGS $CFLAGS -march=$DOCKER_TAG -mtune=$DOCKER_TAG"  \
                CFLAGS="$CFLAGS -march=$DOCKER_TAG -mtune=$DOCKER_TAG"  \
    cmake .. $CONF                                                      \
      -DWITH_HWLOC=ON -DWITH_LIBCPUID=OFF                               \
      -DWITH_HTTP=OFF -DWITH_TLS=ON                                     \
      -DWITH_ASM=ON -DWITH_OPENCL=OFF -DWITH_CUDA=ON -DWITH_NVML=ON     \
      -DWITH_DEBUG_LOG=OFF -DHWLOC_DEBUG=OFF -DCMAKE_BUILD_TYPE=Release \
      -DWITH_CN_LITE=OFF -DWITH_CN_HEAVY=OFF -DWITH_CN_PICO=OFF -DWITH_ARGON2=OFF -DWITH_ASTROBWT=OFF -DWITH_KAWPOW=OFF \
 && make -j`nproc`                                                      \
 && strip --strip-unneeded libxmrig-cuda.so                             \
 && strip --strip-all      libxmrig-cu.a



#FROM nvidia/cuda:11.1-runtime-ubuntu16.04
FROM base

MAINTAINER Innovations Anonymous <InnovAnon-Inc@protonmail.com>
LABEL version="1.0"                                                     \
      maintainer="Innovations Anonymous <InnovAnon-Inc@protonmail.com>" \
      about="Dockerized Crypto Miner"                                   \
      org.label-schema.build-date=$BUILD_DATE                           \
      org.label-schema.license="PDL (Public Domain License)"            \
      org.label-schema.name="Dockerized Crypto Miner"                   \
      org.label-schema.url="InnovAnon-Inc.github.io/docker"             \
      org.label-schema.vcs-ref=$VCS_REF                                 \
      org.label-schema.vcs-type="Git"                                   \
      org.label-schema.vcs-url="https://github.com/InnovAnon-Inc/docker"

# disable interactivity
ARG  DEBIAN_FRONTEND=noninteractive
ENV  DEBIAN_FRONTEND ${DEBIAN_FRONTEND}

WORKDIR /
USER root

# runtime-deps
#libcurl4 libjansson4 zlib1g
#RUN apt install      -y lib32z1
#RUN apt install      -y libgmp10 libmpc3 libmpfr4 libisl15 \
#                        libssl1.0.0 libhwloc5              \
RUN apt-cache search libssl
RUN apt-cache search libmpc
RUN apt-cache search libmpfr
RUN apt-cache search libisl
RUN apt install      -y libssl1.0.0 libgmp10 libmpc3 libmpfr4 libisl15 libhwloc5 \
 && apt autoremove   -y         \
 && apt clean        -y         \
 && rm -rf /var/lib/apt/lists/* \
           /usr/share/info/*    \
           /usr/share/man/*     \
           /usr/share/doc/*
COPY --chown=root --from=libuv /app/build/dest.txz /dest.txz
RUN tar vxf /dest.txz -C / \
 && rm -v /dest.txz
COPY --from=app --chown=root /app/build/xmrig            /usr/local/bin/
COPY --from=lib --chown=root /app/build/libxmrig-cuda.so /usr/local/lib/

ARG COIN=xmr
ENV COIN ${COIN}

COPY "./${COIN}.d/"       /conf.d/
VOLUME                    /conf.d
COPY                --chown=root ./entrypoint.sh /usr/local/bin/entrypoint
USER nobody

#EXPOSE 4048
COPY --chown=root ./healthcheck.sh /usr/local/bin/healthcheck
HEALTHCHECK --start-period=30s --interval=1m --timeout=3s --retries=3 \
CMD ["/usr/local/bin/healthcheck"]

ENTRYPOINT ["/usr/local/bin/entrypoint"]
#CMD        ["btc"]
CMD        ["default"]

