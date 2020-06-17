# ---------------------- BUILD IMAGE ---------------------------------------
FROM golang:1-alpine as builder

ENV GOCARBON_VERSION=0.14.0
ENV CARBONAPI_VERSION=0.13.0
ENV GOPATH=/opt/go

RUN \
  apk update  --no-cache && \
  apk upgrade --no-cache && \
  apk add g++ git make musl-dev cairo-dev

# Install go-carbon

WORKDIR ${GOPATH}

RUN \
  export PATH="${PATH}:${GOPATH}/bin" && \
  mkdir -p \
    /var/log/go-carbon && \
  git clone https://github.com/lomik/go-carbon.git

WORKDIR ${GOPATH}/go-carbon

RUN \
  export PATH="${PATH}:${GOPATH}/bin" && \
  git checkout "tags/v${GOCARBON_VERSION}" 2> /dev/null ; \
  version=$(git describe --tags --always | sed 's/^v//') && \
  echo "build version: ${version}" && \
  make && \
  mv go-carbon /tmp/go-carbon

# Install carbonapi

WORKDIR ${GOPATH}

RUN \
  export PATH="${PATH}:${GOPATH}/bin" && \
  mkdir -p \
    /var/log/carbonapi && \
  git clone https://github.com/go-graphite/carbonapi.git

WORKDIR ${GOPATH}/carbonapi

RUN \
  export PATH="${PATH}:${GOPATH}/bin" && \
  git checkout "tags/${CARBONAPI_VERSION}" 2> /dev/null ; \
  version=${CARBONAPI_VERSION} && \
  echo "build version: ${version}" && \
  make && \
  mv carbonapi /tmp/carbonapi

# ------------------------------ RUN IMAGE --------------------------------------
FROM alpine:3.12

ENV TZ='Etc/UTC'

COPY --from=builder /tmp/go-carbon                         /usr/bin/go-carbon
COPY --from=builder /tmp/carbonapi                         /usr/bin/carbonapi

COPY conf/ /

RUN apk update --no-cache \
  && apk upgrade --no-cache \
  && apk add    --no-cache --virtual .build-deps \
    cairo \
    shadow \
    tzdata \
    runit \
    dcron \
    logrotate \
    libc6-compat \
    ca-certificates \
    su-exec \
    bash \
  && cp "/usr/share/zoneinfo/${TZ}" /etc/localtime \
  && echo "${TZ}" > /etc/timezone \
  && /usr/sbin/useradd \
    --system \
    -U \
    -s /bin/false \
    -c "User for Graphite daemon" \
    carbon \
  && mkdir \
    /var/log/go-carbon \
  && chown -R carbon:carbon /var/log/go-carbon \
  && rm -rf \
    /tmp/* \
    /var/cache/apk/*

WORKDIR /

VOLUME ["/etc/go-carbon", "/etc/carbonapi", "/var/lib/graphite", "/etc/logrotate.d", "/var/log"]

ENV HOME /root

EXPOSE 2003 2003/udp 2004 8080 8081

CMD ["/entrypoint.sh"]
