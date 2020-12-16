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

RUN apt install      -y git build-essential autoconf automake        \
                        libgmp-dev libmpc-dev libmpfr-dev libisl-dev \
                                  libhwloc-dev libssl-dev            \
                        cmake ninja

FROM builder as libuv

ARG CFLAGS="-g0 -Ofast -ffast-math -fassociative-math -freciprocal-math -fmerge-all-constants -fipa-pta -floop-nest-optimize -fgraphite-identity -floop-parallelize-all"
ARG CXXFLAGS
ENV CFLAGS ${CFLAGS}
ENV CXXFLAGS ${CXXFLAGS}

ARG DOCKER_TAG=native
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
 && cmake --build build                                                 \
 && cd       build                                                      \
 && make DESTDIR=dest install                                           \
 && cd           dest                                                   \
 && tar vpacf ../dest.txz --owner root --group root .

FROM builder as app
USER root

ARG CFLAGS="-g0 -Ofast -ffast-math -fassociative-math -freciprocal-math -fmerge-all-constants -fipa-pta -floop-nest-optimize -fgraphite-identity -floop-parallelize-all"
ARG CXXFLAGS
ENV CFLAGS ${CFLAGS}
ENV CXXFLAGS ${CXXFLAGS}

ARG DOCKER_TAG=native
ENV DOCKER_TAG ${DOCKER_TAG}

COPY --chown=root --from=libuv /app/build/dest.txz /dest.txz
RUN tar vxf /dest.txz -C /           \
 && rm -v /dest.txz                  \
 && git clone --depth=1 --recursive  \
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
USER root

ARG CFLAGS="-g0 -Ofast -ffast-math -fassociative-math -freciprocal-math -fmerge-all-constants -fipa-pta -floop-nest-optimize -fgraphite-identity -floop-parallelize-all"
ARG CXXFLAGS
ENV CFLAGS ${CFLAGS}
ENV CXXFLAGS ${CXXFLAGS}

ARG DOCKER_TAG=native
ENV DOCKER_TAG ${DOCKER_TAG}

RUN ls -ltra /usr/local ; exit 2

COPY --chown=root --from=libuv /app/build/dest.txz /dest.txz
RUN tar vxf /dest.txz -C /                \
 && rm -v /dest.txz                       \
 && git clone --depth=1 --recursive       \
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
USER root

#MAINTAINER Innovations Anonymous <InnovAnon-Inc@protonmail.com>
#LABEL version="1.0"                                                     \
#      maintainer="Innovations Anonymous <InnovAnon-Inc@protonmail.com>" \
#      about="Dockerized Crypto Miner"                                   \
#      org.label-schema.build-date=$BUILD_DATE                           \
#      org.label-schema.license="PDL (Public Domain License)"            \
#      org.label-schema.name="Dockerized Crypto Miner"                   \
#      org.label-schema.url="InnovAnon-Inc.github.io/docker"             \
#      org.label-schema.vcs-ref=$VCS_REF                                 \
#      org.label-schema.vcs-type="Git"                                   \
#      org.label-schema.vcs-url="https://github.com/InnovAnon-Inc/docker"
#
## disable interactivity
#ARG  DEBIAN_FRONTEND=noninteractive
#ENV  DEBIAN_FRONTEND ${DEBIAN_FRONTEND}

COPY --chown=root --from=libuv /app/build/dest.txz /dest.txz
RUN apt install      -y libssl1.0.0 libgmp10 libmpc3 libmpfr4 libisl15 libhwloc5 \
 && apt autoremove   -y         \
 && apt clean        -y         \
 && rm -rf /var/lib/apt/lists/* \
           /usr/share/info/*    \
           /usr/share/man/*     \
           /usr/share/doc/*     \
 && tar vxf /dest.txz -C /      \
 && rm -v /dest.txz
COPY --from=app --chown=root /app/build/xmrig            /usr/local/bin/
COPY --from=lib --chown=root /app/build/libxmrig-cuda.so /usr/local/lib/

COPY            --chown=root ./scripts/entrypoint-xmrig.sh  /usr/local/bin/entrypoint

COPY            --chown=root ./scripts/healthcheck.sh /usr/local/bin/healthcheck
HEALTHCHECK --start-period=30s --interval=1m --timeout=3s --retries=3 \
CMD ["/usr/local/bin/healthcheck"]

#USER nobody
#EXPOSE 4048

COPY --chown=root ./scripts/test.sh /test
RUN /test && rm  -v /test

WORKDIR /
ENTRYPOINT ["/usr/local/bin/entrypoint"]
CMD        ["84FEn5Gak63AReZjRtDwV724TsoUtfajxjLHHJZ3zH3vcaAZJwvg4qWdUG9cx7nhA1ZfT9kK89roADmRb1ehLLhH6HyTATK"]

