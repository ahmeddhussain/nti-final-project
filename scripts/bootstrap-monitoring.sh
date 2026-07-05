#!/usr/bin/env bash
set -euo pipefail

KUBECONFIG_PATH="${1:-$WORKSPACE/kubeconfig.yaml}"

if [[ -z "${KUBECONFIG_PATH}" ]]; then
  echo "Usage: $0 <kubeconfig-path>" >&2
  exit 1
fi

export KUBECONFIG="$KUBECONFIG_PATH"

kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -

helm repo add prometheus-community https://prometheus-community.github.io/helm-charts >/dev/null 2>&1 || true
helm repo add grafana https://grafana.github.io/helm-charts >/dev/null 2>&1 || true
helm repo update >/dev/null 2>&1

helm upgrade --install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace \
  --wait --timeout 15m \
  --set prometheus.enabled=true \
  --set grafana.enabled=false \
  --set prometheusOperator.admissionWebhooks.enabled=false \
  --set prometheusOperator.admissionWebhooks.patch.enabled=false \
  --set prometheusOperator.tls.enabled=false

helm upgrade --install grafana grafana/grafana \
  --namespace monitoring \
  --wait --timeout 10m \
  --set adminPassword=admin \
  --set service.type=ClusterIP
