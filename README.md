docker-monero        [![Docker Stars](https://img.shields.io/docker/stars/cornfeedhobo/monero.svg)](https://hub.docker.com/r/cornfeedhobo/monero/)        [![Docker Pulls](https://img.shields.io/docker/pulls/cornfeedhobo/monero.svg)](https://hub.docker.com/r/cornfeedhobo/monero/)
=============

*[monero](http://monero.org) containers based on Ubuntu*


# Pulling
    docker pull cornfeedhobo/monero

# Running the Daemon
    docker run -dit --name monero -v $HOME/.bitmonero:/root/.bitmonero -p 18080:18080 -p 18081:18081 --memory=1g --memory-swap=1g cornfeedhobo/monero

# Checking the container status
    docker logs monero

    curl -X POST http://localhost:18081/json_rpc -d '{"jsonrpc":"2.0","id":"test","method":"get_info"}' -H "Content-Type: application/json" -H "Accept:application/json"


# Using the wallet

## Docker exec
    docker exec -it monero monero-wallet-cli --wallet-file=wallet

## Isolated container
    docker run --rm -it --link monero -v $HOME/.bitmonero:/root/.bitmonero cornfeedhobo/monero monero-wallet-cli --wallet-file=wallet --daemon-address="$MONERO_PORT_18081_TCP_ADDR:$MONERO_PORT_18081_TCP_PORT"

# Running Just the Wallet
    docker run --rm -it -v $HOME/.bitmonero:/root/.bitmonero cornfeedhobo/monero monero-wallet-cli --wallet-file=wallet
