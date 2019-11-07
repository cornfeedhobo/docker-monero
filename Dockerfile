# Multistage docker build, requires docker 17.05

# builder stage
FROM alpine:3.8 as builder

RUN set -ex && apk add --update --no-cache \
		autoconf \
		automake \
		ca-certificates \
		cmake \
		curl \
		dev86 \
		doxygen \
		file \
		g++ \
		git \
		graphviz \
		libtool \
		linux-headers \
		make \
		ncurses-dev \
		pcsc-lite-dev \
		pkgconf

WORKDIR /usr/local

# Boost
ARG BOOST_VERSION=1_68_0
ARG BOOST_VERSION_DOT=1.68.0
ARG BOOST_HASH=7f6130bc3cf65f56a618888ce9d5ea704fa10b462be126ad053e80e553d6d8b7
RUN set -ex \
	&& curl -s -L -o  boost_${BOOST_VERSION}.tar.bz2 https://dl.bintray.com/boostorg/release/${BOOST_VERSION_DOT}/source/boost_${BOOST_VERSION}.tar.bz2 \
	&& echo "${BOOST_HASH}  boost_${BOOST_VERSION}.tar.bz2" | sha256sum -c \
	&& tar -xvf boost_${BOOST_VERSION}.tar.bz2 \
	&& cd boost_${BOOST_VERSION} \
	&& ./bootstrap.sh \
	&& ./b2 \
		--build-type=minimal \
		link=static \
		runtime-link=static \
		--with-chrono \
		--with-date_time \
		--with-filesystem \
		--with-program_options \
		--with-regex \
		--with-serialization \
		--with-system \
		--with-thread \
		--with-locale \
		threading=multi \
		threadapi=pthread \
		cflags="-fPIC" \
		cxxflags="-fPIC" \
		stage
ENV BOOST_ROOT /usr/local/boost_${BOOST_VERSION}

# OpenSSL
ARG OPENSSL_VERSION=1.1.0h
ARG OPENSSL_HASH=5835626cde9e99656585fc7aaa2302a73a7e1340bf8c14fd635a62c66802a517
RUN set -ex \
	&& curl -s -O https://www.openssl.org/source/openssl-${OPENSSL_VERSION}.tar.gz \
	&& echo "${OPENSSL_HASH}  openssl-${OPENSSL_VERSION}.tar.gz" | sha256sum -c \
	&& tar -xzf openssl-${OPENSSL_VERSION}.tar.gz \
	&& cd openssl-${OPENSSL_VERSION} \
	&& ./Configure linux-x86_64 no-shared no-async --static -fPIC \
	&& make build_libs \
	&& make install
ENV OPENSSL_ROOT_DIR=/usr/local/openssl-${OPENSSL_VERSION}

# Sodium
ARG SODIUM_VERSION=1.0.16
ARG SODIUM_HASH=675149b9b8b66ff44152553fb3ebf9858128363d
RUN set -ex \
	&& git clone --depth 1 -b ${SODIUM_VERSION} https://github.com/jedisct1/libsodium.git \
	&& cd libsodium \
	&& test `git rev-parse HEAD` = ${SODIUM_HASH} || exit 1 \
	&& ./autogen.sh \
	&& CFLAGS="-fPIC" CXXFLAGS="-fPIC" ./configure \
	&& make \
	&& make check \
	&& make install

# ZMQ
ARG ZMQ_VERSION=v4.2.5
ARG ZMQ_HASH=d062edd8c142384792955796329baf1e5a3377cd
RUN set -ex \
	&& git clone --depth 1 -b ${ZMQ_VERSION} https://github.com/zeromq/libzmq.git \
	&& cd libzmq \
	&& test `git rev-parse HEAD` = ${ZMQ_HASH} || exit 1 \
	&& ./autogen.sh \
	&& CFLAGS="-fPIC" CXXFLAGS="-fPIC" ./configure --enable-static --disable-shared \
	&& make \
	&& make install \
	&& ldconfig .

# zmq.hpp
ARG CPPZMQ_VERSION=v4.2.3
ARG CPPZMQ_HASH=6aa3ab686e916cb0e62df7fa7d12e0b13ae9fae6
RUN set -ex \
	&& git clone --depth 1 -b ${CPPZMQ_VERSION} https://github.com/zeromq/cppzmq.git \
	&& cd cppzmq \
	&& test `git rev-parse HEAD` = ${CPPZMQ_HASH} || exit 1 \
	&& mv *.hpp /usr/local/include/

# Readline
ARG READLINE_VERSION=7.0
ARG READLINE_HASH=750d437185286f40a369e1e4f4764eda932b9459b5ec9a731628393dd3d32334
RUN set -ex \
	&& curl -s -O https://ftp.gnu.org/gnu/readline/readline-${READLINE_VERSION}.tar.gz \
	&& echo "${READLINE_HASH}  readline-${READLINE_VERSION}.tar.gz" | sha256sum -c \
	&& tar -xzf readline-${READLINE_VERSION}.tar.gz \
	&& cd readline-${READLINE_VERSION} \
	&& CFLAGS="-fPIC" CXXFLAGS="-fPIC" ./configure \
	&& make \
	&& make install

# Monero
ENV MONERO_VERSION=0.14.0.2
ENV MONERO_HASH=6cadbdcd2d952433db3c2422511ed4d13b2cc824
RUN set -ex \
	&& git clone --recursive --depth 1 -b v${MONERO_VERSION} https://github.com/monero-project/monero.git \
	&& cd monero \
	&& git submodule init \
	&& git submodule update \
	&& test `git rev-parse HEAD` = ${MONERO_HASH} || exit 1

ARG NPROC
COPY easylogging.patch /tmp/easylogging.patch
RUN set -ex \
	&& cd monero \
	&& patch -p1 < /tmp/easylogging.patch \
	&& rm -f /tmp/easylogging.patch \
	&& if [ -z "$NPROC" ] ; then export NPROC="1" ; fi \
	&& export Readline_ROOT_DIR="/usr/local" \
	&& nice -n 19 ionice -c2 -n7 make -j$NPROC release-static-linux-x86_64


# runtime stage
FROM alpine:3.8

RUN set -ex && apk add --update --no-cache \
		ncurses-libs \
		pcsc-lite-libs

COPY --from=builder /usr/local/monero/build/Linux/_no_branch_/release/bin/* /usr/local/bin/

# Contains the blockchain and wallet files
VOLUME /root/.bitmonero
WORKDIR /root/.bitmonero

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
