# docs: https://github.com/casey/just
# tmpl: https://github.com/hendrikmaus/justfile-template

set export := true
set dotenv-load := false
set shell := ["bash", "-euo", "pipefail", "-c"]

# call 'just' to get help
@_default:
  just --list --unsorted
  echo ""
  echo "Available variables:"
  just --evaluate | sed 's/^/    /'
  echo ""
  echo "Override variables using 'just key=value ...' (also ALL_UPPERCASE ones)"

# Variables
# ---------

# litecoin version to run
version := "0.18.1"

# docker container metadata
repository := "local/litecoin"
tag := version
image := repository + ":" + tag

# activate docker buildkit
DOCKER_BUILDKIT := "1"

# name of the local kubernetes cluster
cluster := "litecoin-test"

# namespace to use in kubernetes
k8s-namespace := "litecoin"

# Recipes
# -------

# print verbose help (using default pager)
help:
  @cat docs/Justfile.md | ${PAGER:-"less"}

# build linux container image using docker
build-image:
  docker build \
    --progress=plain \
    --build-arg "version={{version}}" \
    --tag "{{image}}" \
    . 2>&1 | just _prefix "containerize"

# push linux container image
push-image:
  docker push "{{image}}"

# render the kubernetes manifests
render:
  helm template litecoind kubernetes/litecoind \
    --namespace "{{k8s-namespace}}" \
    --set-string image.repository="{{repository}}" \
    --set-string image.tag="{{tag}}"

# deploy to local cluster
deploy:
  kubectl get namespace "{{k8s-namespace}}" &>/dev/null \
    || kubectl create namespace "{{k8s-namespace}}"
  just repository="{{repository}}" tag="{{tag}}" render \
    | kubectl --namespace "{{k8s-namespace}}" apply --filename -

# containerize, spawn ephemeral k8s cluster and deploy
test: build-image
  just repository="{{repository}}" tag="{{tag}}" \
    start-k8s import-image | just _prefix "k8s-cluster"
  just repository="{{repository}}" tag="{{tag}}" \
    deploy | just _prefix "deploy"
  @# ^ a slight shortcoming of casey/just v0.10 is that we need to manually
  @# carry on any variables which could have been overridden and used by
  @# recipes called using a sub-shell (see 'deploy' above, for example)
  @# This is not required when using a recipe as direct dependency
  @# as done with 'build-image' in this example.
  @# The sub-shells are used to be able to prefix the output
  @# for improved readability of the log output.

  just _wait-for-k8s "statefulset" "{{k8s-namespace}}" "litecoind"

# start a local kubernetes cluster
start-k8s:
  #!/usr/bin/env bash
  set -euo pipefail

  if ! k3d cluster list | grep -qF "{{cluster}}" &>/dev/null; then
    k3d cluster create "{{cluster}}" \
      --k3s-arg "--disable=traefik@server:0"
  else
    echo "[INFO] Cluster already running:"
    kubectl cluster-info
  fi

  ( just _wait-for-k8s "deployment" "kube-system" "coredns" ) &
  ( just _wait-for-k8s "deployment" "kube-system" "metrics-server" ) &
  ( just _wait-for-k8s "deployment" "kube-system" "local-path-provisioner" ) &

  # shellcheck disable=SC2046
  wait $(jobs -p)

# import container image into local cluster
import-image:
  k3d image import --cluster "{{cluster}}" "{{image}}"

# clean up the test
clean:
  #!/usr/bin/env bash
  set -euo pipefail

  if kubectl cluster-info &>/dev/null; then
    echo "[INFO] decommissioning local kubernetes cluster"
    k3d cluster delete "{{cluster}}"
  fi
  rm "${KUBECONFIG}" &>/dev/null || true

# Utility to wait for k8s resources and follow their rollout
_wait-for-k8s type namespace name:
  #!/usr/bin/env bash
  set -euo pipefail

  until kubectl --namespace "{{namespace}}" get "{{type}}" "{{name}}" &>/dev/null; do
    echo "[INFO] Waiting for {{type}} to appear ..." \
     | just _prefix "{{name}}.{{namespace}}" \
     && sleep 2
  done
  kubectl --namespace "{{namespace}}" \
    rollout status "{{type}}" "{{name}}" --watch=true --timeout=5m \
    | just _prefix "{{name}}.{{namespace}}"

# prefix everything that is piped into this recipe
_prefix prefix:
  @sed -le "s#^#{{prefix}}: #;"
