# Helm Chart For `litecoind`

Run [Litecoin](https://litecoin.org/) on top of Kubernetes.

_Aside: the chart was based on the default `helm create <chart-name>` template._

## Install

```shell
helm install litecoind .
```

By default, the workload will run in `testnet` mode. Use the following command to disable the testnet:

```shell
helm install litecoind . \
  --set container.testnet=false
```

## Uninstall

```shell
helm uninstall litecoind
```

## Configuration

Please see [`values.yaml`](./values.yaml) for all available options.
