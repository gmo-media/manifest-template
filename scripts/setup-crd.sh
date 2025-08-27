#!/usr/bin/env bash

set -euo pipefail

cd "$(dirname "$0")"/..

mkdir -p .crd
cd .crd

# renovate:github-url
wget https://raw.githubusercontent.com/yannh/kubeconform/v0.7.0/scripts/openapi2jsonschema.py
export FILENAME_FORMAT='{fullgroup}-{kind}-{version}'

# renovate:github-url
kustomize build https://github.com/aws/amazon-vpc-resource-controller-k8s//config/default?ref=v1.7.2 > crd.yaml
python3 openapi2jsonschema.py crd.yaml && rm crd.yaml

# renovate:github-url
kustomize build https://github.com/kubernetes-sigs/aws-load-balancer-controller//config/default?ref=v2.13.4 > crd.yaml
python3 openapi2jsonschema.py crd.yaml && rm crd.yaml

# renovate:github-url
python3 openapi2jsonschema.py https://raw.githubusercontent.com/argoproj/argo-cd/v3.1.1/manifests/install.yaml

# renovate:image-tag imageName=public.ecr.aws/karpenter/karpenter
helm template --include-crds oci://public.ecr.aws/karpenter/karpenter --version "1.0.8" > crd.yaml
python3 openapi2jsonschema.py crd.yaml && rm crd.yaml

# renovate:github-url
python3 openapi2jsonschema.py https://raw.githubusercontent.com/traefik/traefik/v3.5.0/docs/content/reference/dynamic-configuration/kubernetes-crd-definition-v1.yml
