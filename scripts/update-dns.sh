#!/usr/bin/env bash
# Upsert dos registros A (apex + wildcard) da zona no Google Cloud DNS.
# Chamado pelo Terraform (null_resource.public_dns); idempotente.
set -euo pipefail

: "${PUBLIC_IP:?defina PUBLIC_IP}"
: "${GCP_PROJECT:?defina GCP_PROJECT}"
: "${DNS_ZONE:?defina DNS_ZONE}"
: "${DOMAIN:?defina DOMAIN}"
: "${SA_KEY:?defina SA_KEY (caminho do key.json)}"

gcloud auth activate-service-account --key-file="$SA_KEY" --quiet

for NAME in "$DOMAIN." "*.$DOMAIN."; do
  if gcloud dns record-sets describe "$NAME" --type=A --zone="$DNS_ZONE" \
    --project="$GCP_PROJECT" >/dev/null 2>&1; then
    gcloud dns record-sets update "$NAME" --type=A --ttl=300 \
      --rrdatas="$PUBLIC_IP" --zone="$DNS_ZONE" --project="$GCP_PROJECT" --quiet
  else
    gcloud dns record-sets create "$NAME" --type=A --ttl=300 \
      --rrdatas="$PUBLIC_IP" --zone="$DNS_ZONE" --project="$GCP_PROJECT" --quiet
  fi
done

echo "DNS ok: $DOMAIN e *.$DOMAIN -> $PUBLIC_IP"
