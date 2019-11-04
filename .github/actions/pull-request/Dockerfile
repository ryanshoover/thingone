FROM alpine

LABEL \
  "name"="Deploy PR Action"

RUN echo http://dl-cdn.alpinelinux.org/alpine/edge/testing >> /etc/apk/repositories && \
  apk add --no-cache git hub

ADD *.sh /

ENTRYPOINT ["/entrypoint.sh"]
