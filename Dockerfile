FROM ubuntu:15.10

ENV MONERO_VERSION 0.11.0.0

ADD entrypoint.sh /

RUN set -ex \
	&& apt-get update \
	&& apt-get install -y ca-certificates curl iputils-ping numactl \
	&& apt-get install -y git build-essential pkgconf cmake libunbound-dev libssl-dev libevent-dev \
		libgtest-dev libdb++-dev libldns-dev libexpat1-dev libbison-dev \
	&& apt-get install -y libboost1.58-dev libboost1.58-doc libboost-date-time1.58-dev \
		libboost-chrono1.58-dev libboost-filesystem1.58-dev libboost-program-options1.58-dev \
		libboost-serialization1.58-dev libboost-system1.58-dev libboost-regex1.58-dev libboost-thread1.58-dev \
	&& rm -rf /var/lib/apt/lists/*

RUN set -ex \
	&& git clone https://github.com/monero-project/bitmonero.git /opt/bitmonero \
	&& cd /opt/bitmonero \
	&& git checkout v$MONERO_VERSION \
	&& nice -n 19 ionice -c2 -n7 make release-static \
	&& mv /opt/bitmonero/build/release/bin/* /usr/bin/ \
	&& cd / \
	&& rm -rf /opt/bitmonero

VOLUME /root/.bitmonero

WORKDIR /root/.bitmonero

EXPOSE 18080 18081

ENTRYPOINT ["/entrypoint.sh"]

CMD ["monerod"]

