# Contributing

## Publishing a new release

1) Update the `VERSION` file to match the release version to be built

1) Build

    ```shell
    ./build.sh "$(< VERSION)-local"
    ```

1) Test

    ```shell
    UID="$(id -u)" GID="$(id -g)" \
    WALLET='do_not_use_test_wallet' \
    TAG="$(< VERSION)-local" \
      docker compose run wallet
    ```

1) Checkout a new branch and commit

    ```shell
    git checkout -b "$(< VERSION)"
    git commit -m "bump to $(< VERSION)"
    ```

1) Push

1) Wait for CI to validate builds

1) Merge to `master`

1) Push
