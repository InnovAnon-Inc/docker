FROM ubuntu:latest as base
#FROM ubuntu:20.04 as base
#FROM ubuntu:18.04 as base
#FROM ubuntu:16.04 as base
#FROM ubuntu:14.04 as base

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

RUN echo ABCDE
RUN apt-cache search libssl
RUN apt-cache search libcurl
RUN apt-cache show libssl-dev

COPY ./scripts/dpkg-dev.list  /dpkg-dev.list
RUN test -f                         /dpkg-dev.list  \
 && apt install -y       `tail -n+2 /dpkg-dev.list` \
 && rm -v                           /dpkg-dev.list

ARG CONF
ENV CONF ${CONF}
ARG CFLAGS="-g0 -Ofast -ffast-math -fassociative-math -freciprocal-math -fmerge-all-constants -fipa-pta -floop-nest-optimize -fgraphite-identity -floop-parallelize-all"
ARG CXXFLAGS
ENV CFLAGS ${CFLAGS}
ENV CXXFLAGS ${CXXFLAGS}

ARG DOCKER_TAG=native
ENV DOCKER_TAG ${DOCKER_TAG}

RUN git clone --depth=1 --recursive   \
   git://github.com/tpruvot/cpuminer-multi.git \
                            /app      \
 && chown -R nobody:nogroup /app
WORKDIR                     /app
USER nobody

# TODO ppc cross compiler
COPY ./scripts/configure-multi.sh  /configure.sh
COPY ./scripts/compile.sh          /compile.sh
RUN                                /compile.sh \
 && strip --strip-all cpuminer

USER root
RUN rm -v                          /configure.sh
#RUN upx --all-filters --ultra-brute cpuminer

FROM base
USER root
WORKDIR /

COPY  ./scripts/dpkg.list  /dpkg.list
RUN test -f                      /dpkg.list  \
 && apt install    -y `tail -n+2 /dpkg.list` \
 && rm -v                        /dpkg.list  \
 && apt autoremove -y                        \
 && apt clean      -y                        \
 && rm -rf /var/lib/apt/lists/*              \
           /usr/share/info/*                 \
           /usr/share/man/*                  \
           /usr/share/doc/*
COPY --chown=root --from=builder \
       /app/cpuminer           /usr/local/bin/cpuminer

ARG COIN=scrypt
ENV COIN ${COIN}

COPY "./mineconf/${COIN}.d/"   /conf.d/
VOLUME                         /conf.d
COPY --chown=root                \
      ./scripts/entrypoint.sh  /usr/local/bin/entrypoint

#EXPOSE 4048

COPY --chown=root                \
      ./scripts/healthcheck.sh /usr/local/bin/healthcheck
HEALTHCHECK --start-period=30s --interval=1m --timeout=3s --retries=3 \
CMD ["/usr/local/bin/healthcheck"]

ARG DOCKER_TAG=native
ENV DOCKER_TAG ${DOCKER_TAG}
COPY --chown=root                \
      ./scripts/test.sh        /test
RUN                            /test \
 && rm -v                      /test

ENTRYPOINT ["/usr/local/bin/entrypoint"]
CMD        ["default"]

