# docker-monero

[![Docker Stars](https://img.shields.io/docker/stars/cornfeedhobo/monero.svg)](https://hub.docker.com/r/cornfeedhobo/monero/)
[![Docker Pulls](https://img.shields.io/docker/pulls/cornfeedhobo/monero.svg)](https://hub.docker.com/r/cornfeedhobo/monero/)

**Built from source [monero](http://getmonero.org) Docker images based on [Alpine Linux](https://alpinelinux.org)**

## TL;DR

```bash
docker compose run --user="$(id -u):$(id -g)" wallet
```

```bash
docker compose down -v
```

## Running the Daemon

```bash
docker run -dit --name monero \
  --user="$(id -u):$(id -g)" \
  --volume="$HOME/.bitmonero:/home/monero/.bitmonero" \
  --publish='18080:18080' \
  --publish='18081:18081' \
  cornfeedhobo/monero
```

## Checking the container status

```bash
docker logs monero
```

```bash
curl -X POST http://localhost:18081/json_rpc \
  -d '{"jsonrpc":"2.0","id":"test","method":"get_info"}' \
  -H 'Content-Type: application/json' \
  -H 'Accept:application/json'
```

## Using the wallet

### Docker exec

```bash
docker exec -it monero monero-wallet-cli
```

### Isolated container

```bash
docker run --rm -it --link monero \
  --user="$(id -u):$(id -g)" \
  --volume="$HOME/.bitmonero:/home/monero/.bitmonero" \
  cornfeedhobo/monero \
    monero-wallet-cli \
      --daemon-address="$MONERO_PORT_18081_TCP_ADDR:$MONERO_PORT_18081_TCP_PORT"
```

_Note: these are special environment variables filled in by the docker daemon and are specific to these examples_.

## Is it any good?

[Yes](http://news.ycombinator.com/item?id=3067434)
