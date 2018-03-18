FROM ubuntu:16.04

ENV MONERO_VERSION 0.11.1.0

ENV MONERO_DEPENDENCIES build-essential \
						iputils-ping \
						curl \
						git \
						numactl \
						pkgconf \
						cmake \
						doxygen \
						graphviz-dev \
						libreadline-dev \
						libunbound-dev \
						libssl-dev \
						libevent-dev \
						libgtest-dev \
						libdb++-dev \
						libldns-dev \
						libexpat1-dev \
						libbison-dev \
						libboost1.58-dev \
						libboost1.58-doc \
						libboost-date-time1.58-dev \
						libboost-chrono1.58-dev \
						libboost-filesystem1.58-dev \
						libboost-program-options1.58-dev \
						libboost-serialization1.58-dev \
						libboost-system1.58-dev \
						libboost-regex1.58-dev \
						libboost-thread1.58-dev

RUN set -ex \
	&& apt-get update \
	&& apt-get install -y ca-certificates \
	&& apt-get install -y $MONERO_DEPENDENCIES \
	&& rm -rf /var/lib/apt/lists/*

RUN set -ex \
	&& git clone https://github.com/monero-project/bitmonero.git /opt/bitmonero \
	&& cd /opt/bitmonero \
	&& git checkout v$MONERO_VERSION \
	&& nice -n 19 ionice -c2 -n7 make release-static \
	&& mv /opt/bitmonero/build/release/bin/* /usr/bin/ \
	&& cd / \
	&& rm -rf /opt/bitmonero

RUN set -ex && apt-get remove -y $MONERO_DEPENDENCIES

ADD entrypoint.sh /

VOLUME /root/.bitmonero

WORKDIR /root/.bitmonero

EXPOSE 18080 18081

ENTRYPOINT ["/entrypoint.sh"]

CMD ["monerod"]
