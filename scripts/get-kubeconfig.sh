#!/usr/bin/env bash
# Busca o kubeconfig do control plane e ajusta para acesso via tunel SSH.
# Uso: ./scripts/get-kubeconfig.sh   (rodar na raiz do repo, na maquina architect)
set -euo pipefail

JUMP="root@139.99.62.36"
CONTROL_PLANE="ubuntu@10.10.10.50"
OUT="./kubeconfig"

scp -o ProxyJump="$JUMP" "$CONTROL_PLANE:/home/ubuntu/.kube/config" "$OUT"

# API só é alcançável pelo túnel; o cert do apiserver não tem SAN para 127.0.0.1,
# então fixamos tls-server-name no nome interno "kubernetes".
sed -i 's|server: https://.*|server: https://127.0.0.1:6443\n    tls-server-name: kubernetes|' "$OUT"
chmod 600 "$OUT"

echo "kubeconfig salvo em $OUT"
echo "Abra o túnel antes do terraform apply:"
echo "  ssh -fN -L 6443:10.10.10.50:6443 $JUMP"
