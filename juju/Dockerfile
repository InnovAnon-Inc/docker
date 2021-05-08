FROM fculpo/zenbot as builder
WORKDIR /tmp
USER root
RUN apk add git tar
USER node
RUN git clone --depth=1 --recursive https://github.com/rountrey/zenbot_strategies.git \
 && cd           zenbot_strategies     \
 && tar acf   ../zenbot_strategies.tgz \
   --exclude=README.md                 \
   --exclude-vcs .                     \
 && cd        ..                       \
 && rm -rf       zenbot_strategies

FROM fculpo/zenbot as final
COPY --from=builder /tmp/zenbot_strategies.tgz /tmp/zenbot_strategies.tgz
USER root
RUN apk add tar \
 && tar xf          /tmp/zenbot_strategies.tgz -C /app/extensions/strategies/ \
 && rm -v           /tmp/zenbot_strategies.tgz

WORKDIR /app
USER node
#ENTRYPOINT ["/usr/local/bin/zenbot"]
#CMD ["trade"]

