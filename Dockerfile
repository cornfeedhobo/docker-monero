FROM ubuntu:16.10 AS builder

RUN set -ex && \
	sed -i 's|archive.ubuntu.com|old-releases.ubuntu.com|g' /etc/apt/sources.list && \
	sed -i 's|security.ubuntu.com|old-releases.ubuntu.com|g' /etc/apt/sources.list && \
	apt-get update && \
	apt-get install -y \
		build-essential \
		ca-certificates \
		cmake \
		curl \
		doxygen \
		git \
		graphviz \
		iputils-ping \
		libbison-dev \
		libboost-all-dev \
		libdb++-dev \
		libevent-dev \
		libexpat1-dev \
		libgtest-dev \
		libldns-dev \
		libminiupnpc-dev \
		libssl-dev \
		libunbound-dev \
		libunwind-dev \
		numactl \
		pkgconf \
		&& \
	rm -rf /var/lib/apt/lists/*

RUN set -ex && \
	git clone \
		--progress \
		--depth=1 \
		--branch=v0.10.0 \
		-- \
		https://github.com/monero-project/monero.git \
		/usr/local/src/monero \
		2>&1 && \
	git clone \
		--progress \
		--depth=1 \
		-- \
		https://github.com/moneroexamples/mymonero-simplewallet.git \
		/usr/local/src/mymonero-simplewallet \
		2>&1

WORKDIR /usr/local/src/monero
RUN nice -n 19 \
		ionice -c2 -n7 \
			make all

WORKDIR /usr/local/src/mymonero-simplewallet
COPY build-mymonero-simplewallet.sh /usr/local/src/mymonero-simplewallet/build-mymonero-simplewallet.sh
RUN bash /usr/local/src/mymonero-simplewallet/build-mymonero-simplewallet.sh

FROM ubuntu:16.10 AS runtime

COPY --from=builder /usr/local/src/monero/build/release/bin/* /usr/local/bin/
COPY --from=builder /usr/local/src/mymonero-simplewallet/mymonerowallet /usr/local/bin/mymonerowallet

RUN set -ex && \
	sed -i 's|archive.ubuntu.com|old-releases.ubuntu.com|g' /etc/apt/sources.list && \
	sed -i 's|security.ubuntu.com|old-releases.ubuntu.com|g' /etc/apt/sources.list && \
	apt-get update && \
	apt install -y \
		$(apt search libboost 2>/dev/null | grep '1\.61' | grep -vE '\-(dev|doc|dbg)' | cut -d'/' -f1 | tr '\n' ' ') \
		libdb5.3++ \
		libevent-2.0-5 \
		libexpat1 \
		libldns1 \
		libminiupnpc10 \
		libssl1.0.0 \
		libunbound2 \
		libunwind8 \
		numactl \
		&& \
	rm -rf /var/lib/apt/lists/*

VOLUME /root/.bitmonero
WORKDIR /root/.bitmonero

EXPOSE 18080 18081

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod 755 /usr/local/bin/entrypoint.sh
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["monerod", "--help"]
