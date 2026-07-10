#!/usr/bin/env bash
# Busca o kubeconfig do control plane (via qm guest exec, sem depender de chave
# SSH nas VMs) e garante o tunel local 6443 para a API do cluster.
# Chamado pelo Terraform (null_resource.cluster_access); tambem roda manual:
#   PUBLIC_HOST=1.2.3.4 CP_IP=10.10.10.50 SSH_PASSWORD=... ./scripts/ensure-access.sh
set -euo pipefail

: "${PUBLIC_HOST:?defina PUBLIC_HOST (IP publico do host Proxmox)}"
: "${CP_IP:?defina CP_IP (IP do control plane)}"
: "${SSH_PASSWORD:?defina SSH_PASSWORD (senha root do host Proxmox)}"
OUT="${KUBECONFIG_OUT:-./kubeconfig}"

export SSHPASS="$SSH_PASSWORD"
SSH_OPTS=(-o StrictHostKeyChecking=accept-new -o ConnectTimeout=15)

run_pve() { sshpass -e ssh "${SSH_OPTS[@]}" "root@$PUBLIC_HOST" "$@"; }

# 1. kubeconfig via guest agent do control plane
VMID=$(run_pve "qm list | awk '/k8s-control-plane-0/{print \$1}'")
[ -n "$VMID" ] || { echo "ERRO: VM k8s-control-plane-0 nao encontrada no Proxmox"; exit 1; }

run_pve "qm guest exec $VMID -- cat /home/ubuntu/.kube/config" |
  jq -re '."out-data"' > "$OUT.tmp"

grep -q 'client-key-data' "$OUT.tmp" || {
  echo "ERRO: kubeconfig invalido/truncado vindo da VM $VMID"
  rm -f "$OUT.tmp"
  exit 1
}

# API so e alcancavel pelo tunel; cert do apiserver nao tem SAN para 127.0.0.1,
# entao fixamos tls-server-name no nome interno "kubernetes".
sed -i "s|server: https://.*|server: https://127.0.0.1:6443\n    tls-server-name: kubernetes|" "$OUT.tmp"
chmod 600 "$OUT.tmp"
mv "$OUT.tmp" "$OUT"

# 2. tunel local 6443 (idempotente)
if ! (exec 3<>/dev/tcp/127.0.0.1/6443) 2>/dev/null; then
  sshpass -e ssh -fN "${SSH_OPTS[@]}" -L "6443:$CP_IP:6443" "root@$PUBLIC_HOST"
fi

echo "acesso ok: kubeconfig=$OUT tunel=127.0.0.1:6443 -> $CP_IP:6443"
