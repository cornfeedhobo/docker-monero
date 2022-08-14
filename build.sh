#!/usr/bin/env bash

set -eu

if [ -n "${DEBUG:-}" ]; then
	set -x
fi

repo='monero-project/monero'
tag="$(< VERSION)"
sha="$(curl -LSs "https://api.github.com/repos/${repo}/git/ref/tags/${tag}" | jq -r '.object.sha')"

build_flags="${1:-}"
build_date="$(date -u +'%Y-%m-%dT%H:%M:%SZ')"
build_script="$(sed -e "s/[[:space:]]\+/ /g" <<-ENDSCRIPT
	docker build ${build_flags} \
		--build-arg BUILD_DATE=${build_date} \
		--build-arg MONERO_VERSION=${tag} \
		--build-arg MONERO_HASH=${sha} \
		--build-arg MONERO_TARGET=release \
		-t cornfeedhobo/monero:${tag} .
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
