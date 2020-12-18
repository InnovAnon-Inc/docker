FROM nvidia/cuda:11.1-devel-ubuntu20.04 as moneroocean-base
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

FROM moneroocean-base as moneroocean-builder

COPY ./scripts/dpkg-dev-xmrig.list /dpkg-dev.list
RUN test -f                        /dpkg-dev.list  \
 && apt install      -y `tail -n+2 /dpkg-dev.list` \
 && rm -v                          /dpkg-dev.list

COPY ./scripts/configure-xmrig.sh /configure.sh

FROM moneroocean-builder as moneroocean-scripts
USER root

# TODO -march -mtune -U
RUN mkdir -v                /app \
 && chown -v nobody:nogroup /app
COPY            --chown=root ./scripts/healthcheck-xmrig.sh /app/healthcheck.sh
COPY            --chown=root ./scripts/entrypoint-xmrig.sh  /app/entrypoint.sh
WORKDIR                                                     /app
USER nobody

ARG CFLAGS="-g0 -Ofast -ffast-math -fassociative-math -freciprocal-math -fmerge-all-constants -fipa-pta -floop-nest-optimize -fgraphite-identity -floop-parallelize-all"
ARG CXXFLAGS
ENV CFLAGS ${CFLAGS}
ENV CXXFLAGS ${CXXFLAGS}

ARG DOCKER_TAG=generic
ENV DOCKER_TAG ${DOCKER_TAG}

RUN shc -Drv -f healthcheck.sh   \
 && shc -Drv -f entrypoint.sh    \
 && test -x     healthcheck.sh.x \
 && test -x     entrypoint.sh.x

FROM moneroocean-builder as moneroocean-libuv
USER root

RUN git clone --depth=1 --recursive  \
    git://github.com/libuv/libuv.git \
    /app                             \
 && chown -R nobody:nogroup /app
WORKDIR                     /app
USER nobody

ARG CFLAGS="-g0 -Ofast -ffast-math -fassociative-math -freciprocal-math -fmerge-all-constants -fipa-pta -floop-nest-optimize -fgraphite-identity -floop-parallelize-all"
ARG CXXFLAGS
ENV CFLAGS ${CFLAGS}
ENV CXXFLAGS ${CXXFLAGS}

ARG DOCKER_TAG=generic
ENV DOCKER_TAG ${DOCKER_TAG}

RUN mkdir -v build                                                      \
 && cd       build                                                      \
 && /configure.sh                                                       \
 && cd       ..                                                         \
 && cmake --build build                                                 \
 && cd       build                                                      \
 && make DESTDIR=dest install                                           \
 && cd           dest                                                   \
 && tar vpacf ../dest.txz --owner root --group root .

FROM moneroocean-builder as moneroocean-lib
USER root

COPY --chown=root --from=moneroocean-libuv /app/build/dest.txz /dest.txz
RUN tar vxf /dest.txz -C /                \
 && rm -v /dest.txz                       \
 && mkdir -v                /app          \
 && chown -v nobody:nogroup /app
WORKDIR                     /app
USER nobody

ARG CFLAGS="-g0 -Ofast -ffast-math -fassociative-math -freciprocal-math -fmerge-all-constants -fipa-pta -floop-nest-optimize -fgraphite-identity -floop-parallelize-all"
ARG CXXFLAGS
ENV CFLAGS ${CFLAGS}
ENV CXXFLAGS ${CXXFLAGS}

ARG DOCKER_TAG=generic
ENV DOCKER_TAG ${DOCKER_TAG}

RUN git clone --depth=1 --recursive       \
    git://github.com/MoneroOcean/xmrig-cuda.git \
    /app                                  \
 && mkdir -v build                                                      \
 && cd       build                                                      \
 && /configure.sh                                                       \
      -DWITH_CN_GPU=OFF -DWITH_ARGON2=OFF -DWITH_ASTROBWT=OFF           \
      -DWITH_CN_LITE=OFF -DWITH_CN_HEAVY=OFF -DWITH_CN_PICO=OFF         \
      -DCUDA_LIB=/usr/local/cuda-11.1/targets/x86_64-linux/lib/stubs/libcuda.so \
 && cd ..                                                               \
 && cmake --build build                                                 \
 && cd            build                                                 \
 && strip --strip-unneeded libxmrig-cuda.so                             \
 && strip --strip-all      libxmrig-cu.a

FROM moneroocean-builder as moneroocean-app
USER root

COPY --chown=root --from=moneroocean-libuv /app/build/dest.txz /dest.txz
COPY --chown=root --from=moneroocean-lib   /app/build/libxmrig-cuda.so \
                               /app/build/libxmrig-cu.a    \
                               /usr/local/lib/
RUN tar vxf /dest.txz -C /           \
 && rm -v /dest.txz                  \
 && mkdir -v                /app     \
 && chown -v nobody:nogroup /app
WORKDIR                     /app
USER nobody

ARG CFLAGS="-g0 -Ofast -ffast-math -fassociative-math -freciprocal-math -fmerge-all-constants -fipa-pta -floop-nest-optimize -fgraphite-identity -floop-parallelize-all"
ARG CXXFLAGS
ENV CFLAGS ${CFLAGS}
ENV CXXFLAGS ${CXXFLAGS}

ARG DOCKER_TAG=generic
ENV DOCKER_TAG ${DOCKER_TAG}

RUN git clone --depth=1 --recursive  \
    git://github.com/MoneroOcean/xmrig.git \
    /app                             \
 && sed -i 's/constexpr const int kMinimumDonateLevel = 1;/constexpr const int kMinimumDonateLevel = 0;/' src/donate.h \
 && mkdir -v build                                                      \
 && cd       build                                                      \
 && /configure.sh                                                       \
      -DWITH_HWLOC=ON -DWITH_LIBCPUID=OFF -DWITH_HTTP=OFF -DWITH_ASM=ON \
      -DWITH_TLS=OFF -DWITH_OPENCL=OFF -DWITH_CUDA=ON -DWITH_NVML=OFF   \
      -DCMAKE_BUILD_TYPE=Release -DWITH_DEBUG_LOG=OFF -DHWLOC_DEBUG=OFF \
      -DWITH_MO_BENCHMARK=ON -DWITH_BENCHMARK=OFF                       \
      -DWITH_CN_GPU=OFF -DWITH_ARGON2=OFF -DWITH_ASTROBWT=OFF           \
      -DWITH_CN_LITE=OFF -DWITH_CN_HEAVY=OFF -DWITH_CN_PICO=OFF         \
 && cd ..                                                               \
 && cmake --build build                                                 \
 && cd            build                                                 \
 && strip --strip-all xmrig-notls
# TODO upx

#FROM nvidia/cuda:11.1-runtime-ubuntu20.04
FROM moneroocean-base
USER root

COPY --chown=root --from=moneroocean-libuv /app/build/dest.txz /dest.txz
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
COPY --from=moneroocean-app --chown=root /app/build/xmrig-notls         /usr/local/bin/xmrig
COPY --from=moneroocean-lib --chown=root /app/build/libxmrig-cuda.so    /usr/local/lib/

ARG COIN=xmr-cuda
ENV COIN ${COIN}
COPY "./mineconf/${COIN}.d/"                                /conf.d/
VOLUME                                                      /conf.d
#COPY            --chown=root ./scripts/entrypoint-xmrig.sh  /usr/local/bin/entrypoint
COPY --from=moneroocean-scripts --chown=root /app/entrypoint.sh.x        /usr/local/bin/entrypoint

#COPY            --chown=root ./scripts/healthcheck-xmrig.sh /usr/local/bin/healthcheck
COPY --from=moneroocean-scripts --chown=root /app/healthcheck.sh.x        /usr/local/bin/healthcheck
HEALTHCHECK --start-period=30s --interval=1m --timeout=3s --retries=3 \
CMD ["/usr/local/bin/healthcheck"]

ARG DOCKER_TAG=generic
ENV DOCKER_TAG ${DOCKER_TAG}
COPY           --chown=root ./scripts/test.sh              /test
RUN                                                        /test test \
 && rm -v                                                  /test

#EXPOSE 4048
WORKDIR /
ENTRYPOINT ["/usr/local/bin/entrypoint"]
CMD        ["default"]

