# Multistage docker build, requires docker 17.05

# builder stage
FROM alpine:3.9 as builder

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
ARG BOOST_VERSION=1_69_0
ARG BOOST_VERSION_DOT=1.69.0
ARG BOOST_HASH=8f32d4617390d1c2d16f26a27ab60d97807b35440d45891fa340fc2648b04406
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
ARG OPENSSL_VERSION=1.1.1b
ARG OPENSSL_HASH=5c557b023230413dfb0756f3137a13e6d726838ccd1430888ad15bfb2b43ea4b
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
ARG SODIUM_VERSION=1.0.17
ARG SODIUM_HASH=b732443c442239c2e0184820e9b23cca0de0828c
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
ARG ZMQ_VERSION=v4.3.1
ARG ZMQ_HASH=2cb1240db64ce1ea299e00474c646a2453a8435b
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
ARG CPPZMQ_VERSION=v4.3.0
ARG CPPZMQ_HASH=213da0b04ae3b4d846c9abc46bab87f86bfb9cf4
RUN set -ex \
	&& git clone --depth 1 -b ${CPPZMQ_VERSION} https://github.com/zeromq/cppzmq.git \
	&& cd cppzmq \
	&& test `git rev-parse HEAD` = ${CPPZMQ_HASH} || exit 1 \
	&& mv *.hpp /usr/local/include/

# Readline
ARG READLINE_VERSION=8.0
ARG READLINE_HASH=e339f51971478d369f8a053a330a190781acb9864cf4c541060f12078948e461
RUN set -ex \
	&& curl -s -O https://ftp.gnu.org/gnu/readline/readline-${READLINE_VERSION}.tar.gz \
	&& echo "${READLINE_HASH}  readline-${READLINE_VERSION}.tar.gz" | sha256sum -c \
	&& tar -xzf readline-${READLINE_VERSION}.tar.gz \
	&& cd readline-${READLINE_VERSION} \
	&& CFLAGS="-fPIC" CXXFLAGS="-fPIC" ./configure \
	&& make \
	&& make install

# Monero
ENV MONERO_VERSION=0.14.1.0
ENV MONERO_HASH=29a505d1c1cfd3baa7d3a0c4433db8d7b043e341
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
FROM alpine:3.9

RUN set -ex && apk add --update --no-cache \
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
