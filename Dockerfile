# Multistage docker build, requires docker 17.05

# builder stage
FROM alpine:3.7 as builder

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
ARG BOOST_VERSION=1_66_0
ARG BOOST_VERSION_DOT=1.66.0
ARG BOOST_HASH=5721818253e6a0989583192f96782c4a98eb6204965316df9f5ad75819225ca9
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
ARG OPENSSL_VERSION=1.0.2n
ARG OPENSSL_HASH=370babb75f278c39e0c50e8c4e7493bc0f18db6867478341a832a982fd15a8fe
RUN set -ex \
	&& curl -s -O https://www.openssl.org/source/openssl-${OPENSSL_VERSION}.tar.gz \
	&& echo "${OPENSSL_HASH}  openssl-${OPENSSL_VERSION}.tar.gz" | sha256sum -c \
	&& tar -xzf openssl-${OPENSSL_VERSION}.tar.gz \
	&& cd openssl-${OPENSSL_VERSION} \
	&& ./Configure linux-x86_64 no-shared --static -fPIC \
	&& make build_crypto build_ssl \
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
ARG ZMQ_VERSION=v4.2.3
ARG ZMQ_HASH=3226b8ebddd9c6c738ba42986822c26418a49afb
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
ARG CPPZMQ_HASH=6aa3ab686e916cb0e62df7fa7d12e0b13ae9fae6
RUN set -ex \
	&& git clone --depth 1 -b ${ZMQ_VERSION} https://github.com/zeromq/cppzmq.git \
	&& cd cppzmq \
	&& test `git rev-parse HEAD` = ${CPPZMQ_HASH} || exit 1 \
	&& mv *.hpp /usr/local/include

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
ENV MONERO_VERSION=0.12.1.0
ENV MONERO_HASH=aa6850c71d2269bd0728ee503ff07f1d52ce5e58
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
	&& if [ -z "$NPROC" ] ; then export NPROC="$(($(nproc)/2))" ; fi \
	&& export Readline_ROOT_DIR="/usr/local" \
	&& nice -n 19 ionice -c2 -n7 make -j$NPROC release-static-linux-x86_64


# runtime stage
FROM alpine:3.7

COPY --from=builder /usr/local/monero/build/release/bin/* /usr/local/bin/

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
