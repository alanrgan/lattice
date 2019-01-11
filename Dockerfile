FROM alpine:latest

RUN apk update && \
	apk add crystal=0.27.0-r0 shards --repository=http://dl-cdn.alpinelinux.org/alpine/edge/community && \
	apk add libc-dev yaml-dev

ADD . /lattice
WORKDIR /lattice

RUN shards install
RUN crystal build --release src/lattice.cr

CMD ./lattice
