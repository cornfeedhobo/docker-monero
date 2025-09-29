# Multistage docker build, requires docker 17.05

ARG ALPINE_TAG=3.22

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
		boost-dev \
		clang-dev \
		cmake \
		cppzmq \
		curl \
		doxygen \
		file \
		gettext \
		git \
		go \
		gperf \
		graphviz-dev \
		hidapi-dev \
		icu-data-full \
		libtool \
		libsodium-dev \
		libudev-zero-dev \
		libusb-dev \
		linux-headers \
		llvm-libunwind-dev \
		make \
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
		--recursive --depth 1 -b ${MONERO_TAG} \
		https://github.com/monero-project/monero.git \
		/usr/src/monero

WORKDIR /usr/src/monero

# patches needed to work with alpine
COPY patches patches
RUN set -ex && \
	patch -p1 < patches/easylogging.patch && \
	patch -p1 < patches/epee.patch && \
	patch -p1 < patches/miniupnpc.patch && \
	patch -p1 < patches/monero.patch

# Build monero, but like, be nice about it.
RUN set -ex && \
	cmake \
		-Wno-dev \
		-B build \
		-G Ninja \
		-D ARCH="x86-64" \
		-D BUILD_64=on \
		-D BUILD_TAG="linux-x64" \
		-D BUILD_TESTS=off \
		-D MANUAL_SUBMODULES=1 \
		-D STACK_TRACE=off \
		-D CMAKE_BUILD_TYPE=Release \
		-D CMAKE_C_COMPILER=clang \
		-D CMAKE_CXX_COMPILER=clang++ \
		-D CMAKE_INSTALL_PREFIX=/usr \
		&& \
	nice -n 19 \
		ionice -c2 -n7 \
			cmake --build build


# Runtime stage
FROM alpine:${ALPINE_TAG} AS runtime

RUN set -ex && \
	apk update && \
	apk upgrade --no-cache && \
	apk add --no-cache \
		boost \
		ca-certificates \
		hidapi \
		libsodium-dev \
		libudev-zero \
		libusb \
		llvm-libunwind \
		openssl \
		rapidjson \
		readline \
		unbound \
		zeromq \
		zlib

COPY --from=builder /root/go/bin/fixuid /usr/local/bin/fixuid
COPY --from=builder /usr/src/monero/build/bin/* /usr/local/bin/

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
