#!/usr/bin/env bash

set -eu

if [[ -n "${DEBUG:+1}" ]]; then
	set -x
fi

monero_tag="$(< VERSION)"

docker_tag="${1:-${monero_tag}}"

build_script=(
	docker
	build
	--progress=plain
	--build-arg="MONERO_TAG=${monero_tag}"
	--tag="cornfeedhobo/monero:${docker_tag}"
	.
)

sed \
	-e "s/[[:space:]]\+-/ \\\\\n    -/g" \
	-e "s/[[:space:]]\+\./ \\\\\n    \./" \
	<<<"${build_script[*]}"

echo 'Are you ready to proceed?'

select confirm in 'Yes' 'No'; do
	case $confirm in
		Yes)
			# shellcheck disable=2048
			exec ${build_script[*]}
			;;
		*)
			exit
			;;
	esac
done
