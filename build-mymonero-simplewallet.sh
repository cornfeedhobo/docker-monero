#!/usr/bin/env bash

set -euo pipefail

rm -rf /opt/monero-dev
mkdir -p /opt/monero-dev/libs
find /usr/local/src/monero/build/release -type f -name '*.a' -exec cp -v {} /opt/monero-dev/libs/ \;;

includes=(
	'-I/usr/local/src/monero/src'
	'-I/usr/local/src/monero/contrib/epee/include'
	'-I/usr/local/src/monero/external'
	'-I/usr/local/src/monero/external/easylogging++'
	'-I/usr/local/src/monero/external/db_drivers/liblmdb'
	'-I/usr/local/src/monero/external/db_drivers/liblmdb/lmdb'
)

cmake \
	-DCMAKE_BUILD_TYPE=Release \
	-DCMAKE_CXX_FLAGS="${includes[*]}" \
	-DCMAKE_EXE_LINKER_FLAGS=-L/local/src/mymonero-simplewallet/build/libs \
	-DMONERO_LIBS_DIR=/usr/local/src/mymonero-simplewallet/build/libs \
	-DMONERO_HEADERS_DIR=/usr/local/src/monero

nice -n 19 ionice -c2 -n7 \
	make mymonerowallet
