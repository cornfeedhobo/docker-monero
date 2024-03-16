#!/bin/sh
set -e

# if thrown flags immediately,
# assume they want to run the blockchain daemon
if [ "$(printf '%s' "$1" | cut -c 1)" = '-' ]; then
	set -- monerod "$@"
fi

# if they are running the blockchain daemon,
# make efficient use of memory
if [ "$1" = 'monerod' ]; then
	numa='numactl --interleave=all'
	if $numa true > /dev/null 2>&1; then
		set -- "${numa}" "$@"
	fi
	# start the daemon using fixuid
	# to adjust permissions if needed
	exec fixuid -q "$@"
fi

# otherwise, don't get in their way
exec "$@"
