#!/usr/bin/env bash

set -eux

repo='monero-project/monero'
branch="$(git rev-parse --abbrev-ref HEAD)"

tag="${branch}"
if [ "${branch}" = 'master' ]; then
	tag="$(curl -LSs "https://api.github.com/repos/${repo}/releases/latest" | jq -r '.tag_name')"
fi

read tag_type tag_sha < <(echo $(curl -LSs "https://api.github.com/repos/${repo}/git/ref/tags/${tag}" | jq -r '.object.type,.object.sha') )
if [ ! $tag_type = 'commit' ]; then
	tag_sha="$(curl -LSs "https://api.github.com/repos/${repo}/git/tags/${tag_sha}" | jq -r '.object.sha')"
fi

build_date="$(date -u +'%Y-%m-%dT%H:%M:%SZ')"
build_flags="${1:-}"

docker build ${build_flags} \
	--build-arg "BUILD_DATE=${build_date}" \
	--build-arg "MONERO_VERSION=${tag}" \
	--build-arg "MONERO_HASH=${tag_sha}" \
	--build-arg "MONERO_TARGET=release" \
	-t cornfeedhobo/monero:${tag} .

docker build ${build_flags} \
	--build-arg "BUILD_DATE=${build_date}" \
	--build-arg "MONERO_VERSION=${tag}" \
	--build-arg "MONERO_HASH=${tag_sha}" \
	--build-arg "MONERO_TARGET=release-static" \
	-t cornfeedhobo/monero:${tag}-static .

if [ "${branch}" = 'master' ]; then
	docker build ${build_flags} \
		--build-arg "BUILD_DATE=${build_date}" \
		--build-arg "MONERO_VERSION=${tag}" \
		--build-arg "MONERO_HASH=${tag_sha}" \
		--build-arg "MONERO_TARGET=release" \
		-t cornfeedhobo/monero:latest .

	docker build ${build_flags} \
		--build-arg "BUILD_DATE=${build_date}" \
		--build-arg "MONERO_VERSION=${tag}" \
		--build-arg "MONERO_HASH=${tag_sha}" \
		--build-arg "MONERO_TARGET=release-static" \
		-t cornfeedhobo/monero:latest-static .
fi
