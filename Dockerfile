# Multistage docker build, requires docker 17.05

# Builder stage
FROM alpine:3.15 as builder

ARG MONERO_VERSION
ARG MONERO_HASH
ARG MONERO_TARGET

RUN set -ex && \
	test -n "${MONERO_HASH}" && \
	test -n "${MONERO_TARGET}" && \
	test -n "${MONERO_VERSION}"

# These steps are broken up so that the builder picks up the layer from the --update command
RUN set -ex && apk --update --no-cache upgrade
RUN set -ex && apk add --no-cache \
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
		go \
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

ENV CFLAGS="-fPIC"
ENV CXXFLAGS="-fPIC -DELPP_FEATURE_CRASH_LOG"

# Build Monero
RUN set -ex \
	&& git clone --recursive --depth 1 -b ${MONERO_VERSION} https://github.com/monero-project/monero.git \
	&& cd monero \
	&& git submodule init \
	&& git submodule update \
	&& nice -n 19 ionice -c2 -n7 make -j${NPROC:-$(nproc)} ${MONERO_TARGET}

# Install fixuid tool
RUN set -ex && \
	go install github.com/boxboat/fixuid@v0.5.1 && \
	chmod 4755 /root/go/bin/fixuid


# Runtime stage
FROM alpine:3.15

ARG MONERO_VERSION
ARG MONERO_HASH
ARG MONERO_TARGET

RUN set -ex && apk --update --no-cache upgrade
RUN set -ex && \
	case "${MONERO_TARGET}" in \
		*static*) apk add --no-cache \
			ca-certificates \
			iputils \
			libexecinfo \
			libsodium \
			ncurses-libs \
			pcsc-lite-libs \
			readline \
			zeromq \
			;; \
		*) apk add --no-cache \
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
			iputils \
			libexecinfo \
			libsodium \
			libusb \
			miniupnpc \
			ncurses-libs \
			numactl-tools \
			openssl \
			pcsc-lite-libs \
			protobuf \
			rapidjson \
			readline \
			unbound-libs \
			zeromq \
			;; \
	esac

COPY --from=builder /root/go/bin/fixuid /usr/local/bin/fixuid
COPY --from=builder /usr/src/monero/build/Linux/_no_branch_/release/bin/* /usr/local/bin/

ADD entrypoint.sh /entrypoint.sh
ENTRYPOINT [ "/entrypoint.sh" ]

# Create a dedicated user and configure fixuid
ARG MONERO_USER="monero"
RUN set -ex && \
	addgroup -g 1000 ${MONERO_USER} && \
	adduser -u 1000 -G ${MONERO_USER} -h /home/${MONERO_USER} -s /bin/ash -D ${MONERO_USER} && \
	mkdir -p /etc/fixuid && \
	printf "user: ${MONERO_USER}\ngroup: ${MONERO_USER}\n" > /etc/fixuid/config.yml
USER "${MONERO_USER}:${MONERO_USER}"

# Contains the blockchain and wallet files
ARG MONERO_HOME="/home/${MONERO_USER}/.bitmonero"
VOLUME ${MONERO_HOME}
WORKDIR ${MONERO_HOME}

CMD [ "monerod", \
		"--p2p-bind-ip=0.0.0.0", \
		"--p2p-bind-port=18080", \
		"--rpc-bind-ip=0.0.0.0", \
		"--rpc-bind-port=18081", \
		"--non-interactive", \
		"--confirm-external-bind" ]

EXPOSE 18080 18081

# Labels, for details see http://label-schema.org/rc1/
ARG BUILD_DATE
LABEL maintainer="github.com/cornfeedhobo/docker-monero"
LABEL org.label-schema.schema-version="1.0"
LABEL org.label-schema.build-date="${BUILD_DATE}"
LABEL org.label-schema.name="cornfeedhobo/monero"
LABEL org.label-schema.description="Built from source monero Docker images based on Alpine Linux"
LABEL org.label-schema.url="https://getmonero.org/"
LABEL org.label-schema.vcs-url="https://github.com/monero-project/monero/"
LABEL org.label-schema.vcs-ref="${MONERO_HASH}"
LABEL org.label-schema.vendor="cornfeedhobo"
LABEL org.label-schema.version="${MONERO_VERSION}"
LABEL org.label-schema.docker.cmd="docker run -dit -p 18080:18080 -p 18081:18081 cornfeedhobo/monero"
