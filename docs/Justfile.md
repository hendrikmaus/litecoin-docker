# Litecoin on Kubernetes

Build a container for `litecoind` and run it on top of Kubernetes.

## Using `just`

The `justfile` provides various recipes to:

- build a container image for `litecoind`
- render Kubernetes manifests
- interact with a local ephemeral testing environment

## Requirements

- [`bash`](https://www.gnu.org/software/bash/)
- [`docker`](https://www.docker.com/)
- [`helm`](https://helm.sh/) (`3.x`)
- [`kubectl`](https://kubernetes.io/docs/tasks/tools/#kubectl)
- [`k3d`](https://k3d.io) (`5.x`)

### Optional

- [`direnv`](https://direnv.net)

## Recipes

### `help`

Print this help.

### `build-image`

Build a container image to run `litecoind`.

Related variables:

- `version` - the version of `litecoind` to run; passed as build argument to the containerization process
- `tag` - defaults to `version`, used as the container image tag
- `repository` - the container registry and image name to use, e.g. `local/litecoind`
- `image` - combines the above into the full image name and tag

_Aside: builds leverage Docker BuildKit by default._

Examples:

- Build the default version:

  ```shell
  just build-image
  ```

- Build a local snapshot:

  ```shell
  just tag=snapshot repository=local/litecoind build-image
  ```

- Disable Docker BuildKit

  ```shell
  just DOCKER_BUILDKIT=false build-image
  ```

### `push-image`

Push the container image to a registry. See [`build-image`](#build-image) for related variables.

### `render`

Render the Kubernetes manifests to `stdout`.

### `deploy`

Deploy the output of [`render`](#render) to the currently active Kubernetes context.

Related variables:

- `k8s-namespace` - the Kubernetes namespace passed to the `helm template` command

Please mind that the namespace will be created if it does not exist.

### `test`

Test the application lifecycle:

- Containerize
- Launch ephemeral Kubernetes cluster (locally)
- Render manifests
- Deploy workload
- Wait for the workload to become ready

This recipe will assert that all parts work together. From containerization, over rendering valid Kubernetes manifests to a running (marked as ready) workload.

### `start-k8s`

Starts a local Kubernetes cluster using the Docker daemon.

Related variables:

- `cluster` - the name of the local cluster (will be prefixed with `k3d-` by the underlying tool)

### `import-image`

Imports the container image into the ephemeral cluster. Only used _after_ [`start-k8s`](#start-k8s) and [`build-image`](#build-image).

Please mind the related variables mentioned in [`build-image`](#build-image).

### `clean`

Cleans up the ephemeral Kubernetes cluster and its context.
