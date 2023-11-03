#!/usr/bin/env bash

set -eu

if [[ -n "${DEBUG:+1}" ]]; then
	set -x
fi

version="$(< VERSION)"

version_sha="$(curl -LSs "https://api.github.com/repos/monero-project/monero/git/ref/tags/${version}" | jq -r '.object.sha')"

build_date="$(date -u +'%Y-%m-%dT%H:%M:%SZ')"

build_tag="${BUILD_TAG:-cornfeedhobo/monero:$version}"

build_script="$(sed -e "s/[[:space:]]\+/ /g" <<-ENDSCRIPT
	docker build ${@} \
		--build-arg BUILD_DATE=${build_date} \
		--build-arg MONERO_VERSION=${version} \
		--build-arg MONERO_HASH=${version_sha} \
		--build-arg MONERO_TARGET=release \
		-t ${build_tag} .
ENDSCRIPT
)"

echo -e "
$(sed -e "s/[[:space:]]\+--/\n  --/g" -e "s/[[:space:]]-t/\n  -t/" <<<"${build_script}")

Are you ready to proceed?
"

select confirm in 'Yes' 'No'; do
	case $confirm in
		Yes)
			exec ${build_script}
			;;
		*)
			exit
			;;
	esac
done
