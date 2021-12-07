# Multistage docker build, requires docker 17.05

# builder stage
FROM alpine:3.13 as builder

RUN set -ex && apk add --update --no-cache \
		autoconf \
		automake \
		boost \
		boost-atomic \
		boost-build \
		boost-build-doc \
		boost-chrono \
		boost-container \
		boost-context \
		boost-contract \
		boost-coroutine \
		boost-date_time \
		boost-dev \
		boost-doc \
		boost-fiber \
		boost-filesystem \
		boost-graph \
		boost-iostreams \
		boost-libs \
		boost-locale \
		boost-log \
		boost-log_setup \
		boost-math \
		boost-prg_exec_monitor \
		boost-program_options \
		boost-python3 \
		boost-random \
		boost-regex \
		boost-serialization \
		boost-stacktrace_basic \
		boost-stacktrace_noop \
		boost-static \
		boost-system \
		boost-thread \
		boost-timer \
		boost-type_erasure \
		boost-unit_test_framework \
		boost-wave \
		boost-wserialization \
		ca-certificates \
		cmake \
		curl \
		dev86 \
		doxygen \
		eudev-dev \
		file \
		g++ \
		git \
		graphviz \
		libexecinfo-dev \
		libsodium-dev \
		libtool \
		libusb-dev \
		linux-headers \
		make \
		miniupnpc-dev \
		ncurses-dev \
		openssl-dev \
		pcsc-lite-dev \
		pkgconf \
		protobuf-dev \
		rapidjson-dev \
		readline-dev \
		unbound-dev \
		zeromq-dev

WORKDIR /usr/src

ARG NPROC
ENV CFLAGS='-fPIC'
ENV CXXFLAGS='-fPIC -DELPP_FEATURE_CRASH_LOG'

# Monero
ENV MONERO_VERSION=0.17.3.0
ENV MONERO_HASH=ab18fea3500841fc312630d49ed6840b3aedb34d
RUN set -ex \
	&& git clone --recursive --depth 1 -b v${MONERO_VERSION} https://github.com/monero-project/monero.git \
	&& cd monero \
	&& test `git rev-parse HEAD` = ${MONERO_HASH} || exit 1 \
	&& git submodule init \
	&& git submodule update \
	&& nice -n 19 ionice -c2 -n7 make -j${NPROC:-$(nproc)} release


# runtime stage
FROM alpine:3.13

RUN set -ex && apk add --update --no-cache \
		boost \
		boost-atomic \
		boost-chrono \
		boost-container \
		boost-context \
		boost-contract \
		boost-coroutine \
		boost-date_time \
		boost-fiber \
		boost-filesystem \
		boost-graph \
		boost-iostreams \
		boost-libs \
		boost-locale \
		boost-log \
		boost-log_setup \
		boost-math \
		boost-prg_exec_monitor \
		boost-program_options \
		boost-python3 \
		boost-random \
		boost-regex \
		boost-serialization \
		boost-stacktrace_basic \
		boost-stacktrace_noop \
		boost-static \
		boost-system \
		boost-thread \
		boost-timer \
		boost-type_erasure \
		boost-unit_test_framework \
		boost-wave \
		boost-wserialization \
		ca-certificates \
		libexecinfo \
		libsodium \
		libusb \
		miniupnpc \
		ncurses-libs \
		openssl \
		pcsc-lite-libs \
		protobuf \
		rapidjson \
		readline \
		unbound-libs \
		zeromq

COPY --from=builder /usr/src/monero/build/Linux/_no_branch_/release/bin/* /usr/local/bin/

# Contains the blockchain and wallet files
ENV MONERO_HOME "/root/.bitmonero"
VOLUME $MONERO_HOME
WORKDIR $MONERO_HOME

ADD entrypoint.sh /entrypoint.sh
ENTRYPOINT [ "/entrypoint.sh" ]

CMD [ "monerod", \
		"--p2p-bind-ip=0.0.0.0", \
		"--p2p-bind-port=18080", \
		"--rpc-bind-ip=0.0.0.0", \
		"--rpc-bind-port=18081", \
		"--non-interactive", \
		"--confirm-external-bind" ]

EXPOSE 18080 18081
