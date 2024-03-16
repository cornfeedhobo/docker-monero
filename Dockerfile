# Multistage docker build, requires docker 17.05

# Builder stage
FROM alpine:edge as builder

ARG MONERO_TAG
RUN test -n "${MONERO_TAG}"

RUN set -ex && \
	apk update && \
	apk upgrade --no-cache && \
	apk add --no-cache \
		autoconf \
		automake \
		cmake \
		curl \
		doxygen \
		file \
		g++ \
		gettext \
		git \
		go \
		gperf \
		libtool \
		linux-headers \
		make \
		patch \
		perl \
		python3 \
		zlib-dev

# Alpine doesn't package this anymore, and it's been archived on github.
# This is dirty and won't last forever. It might be worth embedding soon.
RUN apk add --no-cache \
		--repository=http://dl-cdn.alpinelinux.org/alpine/v3.16/main \
		libexecinfo-dev

# Build the fixuid tool
RUN set -ex && \
	go install github.com/boxboat/fixuid@v0.5.1 && \
	chmod 4755 /root/go/bin/fixuid

# Clone Monero and submodules
RUN git clone \
		--recursive --depth 1 -b ${MONERO_TAG} \
		https://github.com/monero-project/monero.git \
		/usr/src/monero

WORKDIR /usr/src/monero

# This is patched on master, but didn't make it into this release.
COPY epee.stdint.patch epee.stdint.patch
RUN patch -p1 < epee.stdint.patch

# Set flags that make it possible to compile against musl.
ENV CFLAGS="-fPIC -DELPP_FEATURE_CRASH_LOG -DSTACK_TRACE=OFF"
ENV CXXFLAGS="-fPIC -DELPP_FEATURE_CRASH_LOG -DSTACK_TRACE=OFF"
ENV LDFLAGS="-Wl,-V"

# Build dependencies and monero, but like, be nice about it.
RUN nice -n 19 \
		ionice -c2 -n7 \
			make -j${NPROC:-$(( $(nproc) - 1 ))} depends target=x86_64-linux-gnu


# Runtime stage
FROM alpine:edge as runtime

RUN set -ex && \
	apk update && \
	apk upgrade --no-cache && \
	apk add --no-cache \
		ca-certificates

# Alpine doesn't package this anymore, and it's been archived on github.
# This is dirty and won't last forever. It might be worth embedding soon.
RUN apk add --no-cache \
		--repository=http://dl-cdn.alpinelinux.org/alpine/v3.16/main \
		libexecinfo

COPY --from=builder /root/go/bin/fixuid /usr/local/bin/fixuid
COPY --from=builder /usr/src/monero/build/x86_64-linux-gnu/release/bin/* /usr/local/bin/

# Create a dedicated user and configure fixuid
ARG MONERO_USER="monero"
RUN set -ex && \
	addgroup -g 1000 ${MONERO_USER} && \
	adduser -u 1000 -G ${MONERO_USER} -h /home/${MONERO_USER} -s /bin/ash -D ${MONERO_USER} && \
	mkdir -p /etc/fixuid && \
	printf "user: ${MONERO_USER}\ngroup: ${MONERO_USER}\n" > /etc/fixuid/config.yml
USER "${MONERO_USER}:${MONERO_USER}"

# Define a volume for the blockchain and wallet files
ARG MONERO_HOME="/home/${MONERO_USER}/.bitmonero"
VOLUME ${MONERO_HOME}
WORKDIR ${MONERO_HOME}

COPY entrypoint.sh /entrypoint.sh
ENTRYPOINT [ "/entrypoint.sh" ]
CMD [ "monerod", \
		"--p2p-bind-ip=0.0.0.0", \
		"--p2p-bind-port=18080", \
		"--rpc-bind-ip=0.0.0.0", \
		"--rpc-bind-port=18081", \
		"--non-interactive", \
		"--confirm-external-bind" ]

EXPOSE 18080 18081
