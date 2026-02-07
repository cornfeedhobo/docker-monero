# docker-monero

[![Docker Stars](https://img.shields.io/docker/stars/cornfeedhobo/monero.svg)](https://hub.docker.com/r/cornfeedhobo/monero/)
[![Docker Pulls](https://img.shields.io/docker/pulls/cornfeedhobo/monero.svg)](https://hub.docker.com/r/cornfeedhobo/monero/)

**Built from source [monero](http://getmonero.org) Docker images based on [Alpine Linux](https://alpinelinux.org)**

**[fixuid](https://github.com/boxboat/fixuid) included**

## Docker Compose

Docker Compose is included as a convenience to get you running immediately.

Note: _Docker Compose can be installed as a plugin or a standalone command_.
      _Adjust your commands according to your install_.

### Supported environment variables

| Name     | Default Value    |
| -------- | ---------------- |
| UID      | 1000             |
| GID      | 1000             |
| TAG      | latest           |
| DATA_DIR | $HOME/.bitmonero |

### Launch wallet while daemon syncs in the background

```bash
UID="$(id -u)" GID="$(id -g)" docker compose run wallet
```

### Destroy everything

```bash
docker compose down -v
```

## Docker

### Running the Daemon

```bash
docker run -dit --name monero \
  --user="$(id -u):$(id -g)" \
  --volume="$HOME/.bitmonero:/home/monero/.bitmonero" \
  --publish='18080:18080' \
  --publish='18081:18081' \
  cornfeedhobo/monero
```

### Checking the daemon status

```bash
docker logs monero
```

```bash
curl -X POST http://localhost:18081/json_rpc \
  -d '{"jsonrpc":"2.0","id":"test","method":"get_info"}' \
  -H 'Content-Type: application/json' \
  -H 'Accept:application/json'
```

### Using the wallet

#### Docker exec

To run in the same container as the running daemon:

```bash
docker exec -it monero monero-wallet-cli
```

#### Isolated container

To run in a different container than the running daemon:

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
