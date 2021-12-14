#!/usr/bin/env bash

set -eu

if [ -n "${DEBUG:-}" ]; then
	set -x
fi

repo='monero-project/monero'
branch="$(git rev-parse --abbrev-ref HEAD)"

tag="${branch}"
declare -a tags=( "${tag}" )
if [ "${branch}" = 'master' ]; then
	tag="$(curl -LSs "https://api.github.com/repos/${repo}/releases/latest" | jq -r '.tag_name')"
	tags=( "${tag}" 'latest')
fi

read -r tag_type tag_sha < <(curl -LSs "https://api.github.com/repos/${repo}/git/ref/tags/${tag}" | jq -r '.object.type,.object.sha')
if [ ! "${tag_type}" = 'commit' ]; then
	tag_sha="$(curl -LSs "https://api.github.com/repos/${repo}/git/tags/${tag_sha}" | jq -r '.object.sha')"
fi

build_date="$(date -u +'%Y-%m-%dT%H:%M:%SZ')"
build_flags="${1:-}"

build_script=''
for t in "${tags[@]}"; do
	for s in '' '-static'; do
		build_script+="$(cat <<-ENDSCRIPT
			docker build ${build_flags} \
				--build-arg "BUILD_DATE=${build_date}" \
				--build-arg "MONERO_VERSION=${tag}" \
				--build-arg "MONERO_HASH=${tag_sha}" \
				--build-arg "MONERO_TARGET=release${s}" \
				-t cornfeedhobo/monero:${t}${s} .
		ENDSCRIPT
		)"
		build_script+=$'\n'
	done
done
build_script="$(sed -e "s/[[:space:]]\+/ /g" <<< "${build_script}")"

echo -e "${build_script}\n"

echo 'Are you ready to proceed?'
select confirm in 'Yes' 'No'; do
	case $confirm in
		Yes)
			eval "${build_script}"
			exit
			;;
		*)
			exit
			;;
	esac
done
