# Multistage docker build, requires docker 17.05

# builder stage
FROM alpine:3.10 as builder

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
		boost-python2 \
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

# zmq.hpp
ARG CPPZMQ_VERSION=v4.4.1
ARG CPPZMQ_HASH=f5b36e563598d48fcc0d82e589d3596afef945ae
RUN set -ex \
	&& git clone --depth 1 -b ${CPPZMQ_VERSION} https://github.com/zeromq/cppzmq.git \
	&& cd cppzmq \
	&& test `git rev-parse HEAD` = ${CPPZMQ_HASH} || exit 1 \
	&& mkdir /usr/local/include \
	&& mv *.hpp /usr/local/include/

WORKDIR /usr/local

ARG NPROC
ENV CFLAGS='-fPIC'
ENV CXXFLAGS='-fPIC -DELPP_FEATURE_CRASH_LOG'

# Monero
ENV MONERO_VERSION=0.17.1.0
ENV MONERO_HASH=4d855fcca7db286484c256d85619c051a55592ad
RUN set -ex \
	&& git clone --recursive --depth 1 -b v${MONERO_VERSION} https://github.com/monero-project/monero.git \
	&& cd monero \
	&& git submodule init \
	&& git submodule update \
	&& test `git rev-parse HEAD` = ${MONERO_HASH} || exit 1 \
	&& nice -n 19 ionice -c2 -n7 make -j${NPROC:-1} release-static-linux-x86_64


# runtime stage
FROM alpine:3.10

RUN set -ex && apk add --update --no-cache \
		ca-certificates \
		libexecinfo \
		libsodium \
		ncurses-libs \
		pcsc-lite-libs

COPY --from=builder /usr/local/monero/build/Linux/_no_branch_/release/bin/* /usr/local/bin/

ENV MONERO_HOME "/root/.bitmonero"

# Contains the blockchain and wallet files
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
