# Multistage docker build, requires docker 17.05

ARG ALPINE_TAG=3.23

# Builder stage
FROM alpine:${ALPINE_TAG} AS builder

ARG MONERO_TAG
RUN test -n "${MONERO_TAG}"

RUN set -ex && \
	apk update && \
	apk upgrade && \
	apk add \
		autoconf \
		automake \
		bison \
		boost-dev \
		build-base \
		ccache \
		cmake \
		cppzmq \
		curl \
		doxygen \
		expat-dev \
		file \
		gettext-dev \
		git \
		go \
		gperf \
		graphviz \
		graphviz-dev \
		gtest-dev \
		hidapi-dev \
		icu-data-full \
		iputils \
		ldns-dev \
		libevent-dev \
		libsodium-dev \
		libtool \
		libudev-zero-dev \
		libusb-dev \
		linux-headers \
		make \
		miniupnpc-dev \
		openssl-dev \
		patch \
		perl \
		python3 \
		qt5-qttools-dev \
		rapidjson-dev \
		readline-dev \
		samurai \
		unbound-dev \
		zeromq-dev \
		zlib-dev

# Build the fixuid tool
RUN set -ex && \
	go install github.com/boxboat/fixuid@v0.5.1 && \
	chmod 4755 /root/go/bin/fixuid

# Clone Monero and submodules
RUN git clone \
	--progress --depth 1 \
	--recursive -b ${MONERO_TAG} \
	-- \
	https://github.com/monero-project/monero.git \
	/usr/local/src/monero \
	2>&1

WORKDIR /usr/local/src/monero

# Apply patches needed to work with alpine
COPY patches patches
RUN set -ex && \
	patch -p1 < patches/easylogging.patch && \
	patch -p1 < patches/epee.patch && \
	patch -p1 < patches/miniupnpc.patch && \
	patch -p1 < patches/monero.patch

# Build monero, but like, be nice about it.
RUN set -ex && \
	cmake \
		-B build \
		-D ARCH="x86-64" \
		-D Boost_USE_STATIC_LIBS=off \
		-D BOOST_INCLUDEDIR=/usr/include \
		-D BOOST_LIBRARYDIR=/usr/lib \
		-D BOOST_ROOT=/usr \
		-D BUILD_64=on \
		-D BUILD_SHARED_LIBS=on \
		-D BUILD_TAG="linux-x64" \
		-D BUILD_TESTS=off \
		-D CMAKE_BUILD_TYPE=Release \
		-D CMAKE_C_COMPILER=gcc \
		-D CMAKE_CXX_COMPILER=g++ \
		-D CMAKE_PREFIX_PATH=/usr \
		-D MANUAL_SUBMODULES=1 \
		-D STACK_TRACE=off \
		-D STATIC=off \
		-G Ninja \
		-S . \
		-Wno-dev \
		&& \
	nice -n 19 ionice -c2 -n7 \
		cmake --build build


# Runtime stage
FROM alpine:${ALPINE_TAG} AS runtime

RUN set -ex && \
	apk update && \
	apk upgrade --no-cache && \
	apk add --no-cache \
		boost \
		ca-certificates \
		expat \
		gettext \
		hidapi \
		ldns \
		libevent \
		libsodium \
		libudev-zero \
		libunwind \
		libusb \
		miniupnpc \
		openssl \
		rapidjson \
		readline \
		unbound \
		zeromq \
		zlib

COPY --from=builder /root/go/bin/fixuid /usr/local/bin/fixuid

COPY --from=builder /usr/local/src/monero/build/bin/* /usr/local/bin/

COPY --from=builder /usr/local/src/monero/build/src/*.so /usr/local/lib/

COPY --from=builder /usr/local/src/monero/build/src/*/*.so /usr/local/lib/

COPY --from=builder /usr/local/src/monero/build/src/*/*/*.so /usr/local/lib/

COPY --from=builder /usr/local/src/monero/build/contrib/*/*/*.so /usr/local/lib/

COPY --from=builder /usr/local/src/monero/build/external/*/*.so /usr/local/lib/

COPY --from=builder /usr/local/src/monero/build/external/*/*/*.so /usr/local/lib/

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
		"--zmq-rpc-bind-ip=0.0.0.0", \
		"--zmq-rpc-bind-port=18082", \
		"--zmq-pub=tcp://0.0.0.0:18083", \
		"--non-interactive", \
		"--confirm-external-bind" ]

EXPOSE 18080 18081 18082 18083
