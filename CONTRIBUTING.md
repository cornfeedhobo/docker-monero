# Contributing

## Building locally

```shell
BUILD_TAG='my-monero-build' ./build.sh
```

## Publishing a new release

1) Update the `VERSION` file to match the release version to be built

1) Build

1) Test

1) Checkout a new branch and commit

    ```shell
    git checkout -b "$(< VERSION)"
    git commit -m "bump to $(< VERSION)"
    ```

1) Push

1) Wait for CI to validate builds

1) Merge to `master`

1) Push
