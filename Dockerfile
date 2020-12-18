FROM nvidia/cuda:11.1-devel-ubuntu20.04 as base
#FROM nvidia/cuda:9.1-devel-ubuntu16.04 as base

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

ARG  DEBIAN_FRONTEND=noninteractive
ENV  DEBIAN_FRONTEND ${DEBIAN_FRONTEND}

ARG  TZ=UTC
ENV  TZ ${TZ}
ARG  LANG=C.UTF-8
ENV  LANG ${LANG}
ARG  LC_ALL=C.UTF-8
ENV  LC_ALL ${LC_ALL}

RUN apt update \
 && apt full-upgrade -y

FROM base as builder

COPY ./scripts/dpkg-dev-xmrig.list /dpkg-dev.list
RUN test -f                        /dpkg-dev.list  \
 && apt install      -y `tail -n+2 /dpkg-dev.list` \
 && rm -v                          /dpkg-dev.list

COPY ./scripts/configure-xmrig.sh /configure.sh

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
#COPY ./scripts/configure-xmrig.sh /configure.sh
RUN mkdir -v build                                                      \
 && cd       build                                                      \
 && /configure.sh                                                       \
 && cd       ..                                                         \
 && cmake --build build                                                 \
 && cd       build                                                      \
 && make DESTDIR=dest install                                           \
 && cd           dest                                                   \
 && tar vpacf ../dest.txz --owner root --group root .

#USER root
#RUN rm -v                         /configure.sh

FROM builder as lib
USER root

ARG CFLAGS="-g0 -Ofast -ffast-math -fassociative-math -freciprocal-math -fmerge-all-constants -fipa-pta -floop-nest-optimize -fgraphite-identity -floop-parallelize-all"
ARG CXXFLAGS
ENV CFLAGS ${CFLAGS}
ENV CXXFLAGS ${CXXFLAGS}

ARG DOCKER_TAG=native
ENV DOCKER_TAG ${DOCKER_TAG}

COPY --chown=root --from=libuv /app/build/dest.txz /dest.txz
RUN tar vxf /dest.txz -C /                \
 && rm -v /dest.txz                       \
 && git clone --depth=1 --recursive       \
    git://github.com/MoneroOcean/xmrig-cuda.git \
    /app                                  \
 && chown -R nobody:nogroup /app
WORKDIR                     /app
USER nobody
#COPY ./scripts/configure-xmrig.sh /configure.sh

# TODO WITH_CN_R=OFF ?
RUN mkdir -v build                                                      \
 && cd       build                                                      \
 && /configure.sh                                                       \
      -DWITH_CN_R=ON -DWITH_CN_LITE=ON -DWITH_CN_HEAVY=ON               \
      -DWITH_CN_PICO=ON -DWITH_ARGON2=OFF -DWITH_CN_GPU=ON              \
      -DWITH_RANDOMX=ON -DWITH_ASTROBWT=ON -DWITH_KAWPOW=ON             \
      -DCUDA_LIB=/usr/local/cuda-11.1/targets/x86_64-linux/lib/stubs/libcuda.so \
 && cd ..                                                               \
 && cmake --build build                                                 \
 && cd            build                                                 \
 && strip --strip-unneeded libxmrig-cuda.so                             \
 && strip --strip-all      libxmrig-cu.a

#USER root
#RUN rm -v /configure.sh

FROM builder as app
USER root

ARG CFLAGS="-g0 -Ofast -ffast-math -fassociative-math -freciprocal-math -fmerge-all-constants -fipa-pta -floop-nest-optimize -fgraphite-identity -floop-parallelize-all"
ARG CXXFLAGS
ENV CFLAGS ${CFLAGS}
ENV CXXFLAGS ${CXXFLAGS}

ARG DOCKER_TAG=native
ENV DOCKER_TAG ${DOCKER_TAG}

COPY --chown=root --from=libuv /app/build/dest.txz /dest.txz
COPY --chown=root --from=lib   /app/build/libxmrig-cuda.so \
                               /app/build/libxmrig-cu.a    \
                               /usr/local/lib/
RUN tar vxf /dest.txz -C /           \
 && rm -v /dest.txz                  \
 && git clone --depth=1 --recursive  \
    git://github.com/MoneroOcean/xmrig.git \
    /app                             \
 && chown -R nobody:nogroup /app
WORKDIR                     /app
USER nobody
#COPY ./scripts/configure-xmrig.sh /configure.sh
RUN sed -i 's/constexpr const int kMinimumDonateLevel = 1;/constexpr const int kMinimumDonateLevel = 0;/' src/donate.h \
 && mkdir -v build                                                      \
 && cd       build                                                      \
 && /configure.sh                                                       \
      -DWITH_HWLOC=ON -DWITH_LIBCPUID=OFF -DWITH_HTTP=OFF -DWITH_ASM=ON \
      -DWITH_TLS=OFF -DWITH_OPENCL=OFF -DWITH_CUDA=ON -DWITH_NVML=OFF   \
      -DCMAKE_BUILD_TYPE=Release -DWITH_DEBUG_LOG=OFF -DHWLOC_DEBUG=OFF \
      -DWITH_MO_BENCHMARK=ON -DWITH_BENCHMARK=OFF                       \
      -DWITH_CN_LITE=OFF -DWITH_CN_PICO=ON -DWITH_CN_HEAVY=ON            \
      -DWITH_CN_GPU=ON -DWITH_RANDOMX=ON -DWITH_ARGON2=OFF              \
      -DWITH_ASTROBWT=OFF -DWITH_KAWPOW=OFF                              \
#      -DWITH_CN_LITE=ON -DWITH_CN_PICO=ON -DWITH_CN_HEAVY=ON            \
#      -DWITH_CN_GPU=ON -DWITH_RANDOMX=ON -DWITH_ARGON2=OFF              \
#      -DWITH_ASTROBWT=ON -DWITH_KAWPOW=ON                               \
 && cd ..                                                               \
 && cmake --build build                                                 \
 && cd            build                                                 \
 && strip --strip-all xmrig-notls
#RUN upx --all-filters --ultra-brute cpuminer

#USER root
#RUN rm -v /configure.sh

#FROM nvidia/cuda:11.1-runtime-ubuntu20.04
FROM base
USER root

COPY --chown=root --from=libuv /app/build/dest.txz /dest.txz
COPY ./scripts/dpkg-xmrig-cpu.list /dpkg.list
RUN test -f                        /dpkg.list  \
 && apt install      -y `tail -n+2 /dpkg.list` \
 && rm -v                          /dpkg.list  \
 && apt autoremove   -y         \
 && apt clean        -y         \
 && rm -rf /var/lib/apt/lists/* \
           /usr/share/info/*    \
           /usr/share/man/*     \
           /usr/share/doc/*     \
 && tar vxf /dest.txz -C /      \
 && rm -v /dest.txz
COPY --from=app --chown=root /app/build/xmrig-notls         /usr/local/bin/xmrig
COPY --from=lib --chown=root /app/build/libxmrig-cuda.so    /usr/local/lib/

#COPY ./mineconf/xmrig.json   /conf.d/default.json
ARG COIN=xmr-cuda
ENV COIN ${COIN}
COPY "./mineconf/${COIN}.d/"                                /conf.d/
VOLUME                                                      /conf.d
COPY            --chown=root ./scripts/entrypoint-xmrig.sh  /usr/local/bin/entrypoint

COPY            --chown=root ./scripts/healthcheck-xmrig.sh /usr/local/bin/healthcheck
HEALTHCHECK --start-period=30s --interval=1m --timeout=3s --retries=3 \
CMD ["/usr/local/bin/healthcheck"]

#USER nobody
#EXPOSE 4048

ARG DOCKER_TAG=native
ENV DOCKER_TAG ${DOCKER_TAG}
COPY           --chown=root ./scripts/test.sh              /test
RUN                                                        /test test \
 && rm -v                                                  /test

WORKDIR /
ENTRYPOINT ["/usr/local/bin/entrypoint"]
CMD        ["default"]

