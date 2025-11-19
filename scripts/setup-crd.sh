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
kustomize build https://github.com/kubernetes-sigs/aws-load-balancer-controller//config/default?ref=v2.15.0 > crd.yaml
python3 openapi2jsonschema.py crd.yaml && rm crd.yaml

# renovate:github-url
python3 openapi2jsonschema.py https://raw.githubusercontent.com/argoproj/argo-cd/v3.2.0/manifests/install.yaml

# renovate:image-tag imageName=public.ecr.aws/karpenter/karpenter
helm template --include-crds oci://public.ecr.aws/karpenter/karpenter --set settings.clusterName=test --version "1.8.1" > crd.yaml
python3 openapi2jsonschema.py crd.yaml && rm crd.yaml

# renovate:github-url
python3 openapi2jsonschema.py https://raw.githubusercontent.com/traefik/traefik/v3.6.2/docs/content/reference/dynamic-configuration/kubernetes-crd-definition-v1.yml

# renovate:github-url
python3 openapi2jsonschema.py https://github.com/kyverno/kyverno/releases/download/v1.16.0/install.yaml

# renovate:general datasource=helm depName=prometheus-operator-crds registryUrl=https://prometheus-community.github.io/helm-charts
helm template --include-crds --repo https://prometheus-community.github.io/helm-charts --set settings.clusterName=test prometheus-operator-crds --version "24.0.2" > crd.yaml
python3 openapi2jsonschema.py crd.yaml && rm crd.yaml

# renovate:general datasource=helm depName=victoria-metrics-k8s-stack registryUrl=https://victoriametrics.github.io/helm-charts/
helm template --include-crds --repo https://victoriametrics.github.io/helm-charts/ --set settings.clusterName=test victoria-metrics-k8s-stack --version "0.63.6" > crd.yaml
python3 openapi2jsonschema.py crd.yaml && rm crd.yaml
