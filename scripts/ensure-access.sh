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
PORT="${TUNNEL_PORT:-16443}"

export SSHPASS="$SSH_PASSWORD"
SSH_OPTS=(-o StrictHostKeyChecking=accept-new -o ConnectTimeout=15)

run_pve() { sshpass -e ssh "${SSH_OPTS[@]}" "root@$PUBLIC_HOST" "$@"; }

# 1. kubeconfig via guest agent do control plane
VMID=$(run_pve "qm list | awk '/k8s-control-plane-0/{print \$1}'")
[ -n "$VMID" ] || { echo "ERRO: VM k8s-control-plane-0 nao encontrada no Proxmox"; exit 1; }

# O kubeadm init roda no cloud-init da VM e demora varios minutos apos a
# criacao; espera ate 20 min pelo kubeconfig ficar disponivel.
ok=""
for i in $(seq 1 80); do
  if run_pve "qm guest exec $VMID -- cat /home/ubuntu/.kube/config" 2>/dev/null |
       jq -re '."out-data"' > "$OUT.tmp" 2>/dev/null &&
     grep -q 'client-key-data' "$OUT.tmp"; then
    ok=1
    break
  fi
  rm -f "$OUT.tmp"
  echo "aguardando kubeconfig na VM $VMID ($((i*15))s)..."
  sleep 15
done
[ -n "$ok" ] || { echo "ERRO: kubeconfig indisponivel apos 20 min (bootstrap kubeadm falhou?)"; exit 1; }

# API so e alcancavel pelo tunel; cert do apiserver nao tem SAN para 127.0.0.1,
# entao fixamos tls-server-name no nome interno "kubernetes". Porta local
# 16443 para nao conflitar com outros k8s locais (Docker Desktop usa 6443).
sed -i "s|server: https://.*|server: https://127.0.0.1:$PORT\n    tls-server-name: kubernetes|" "$OUT.tmp"
chmod 600 "$OUT.tmp"
mv "$OUT.tmp" "$OUT"

# 2. tunel local 16443 (idempotente)
if ! (exec 3<>/dev/tcp/127.0.0.1/$PORT) 2>/dev/null; then
  sshpass -e ssh -fN "${SSH_OPTS[@]}" -o ServerAliveInterval=30 -L "$PORT:$CP_IP:6443" "root@$PUBLIC_HOST"
fi

# 3. API precisa responder pelo tunel antes do helm/kubectl usarem o kubeconfig
for i in $(seq 1 24); do
  curl -ks -m 5 --resolve kubernetes:$PORT:127.0.0.1 "https://kubernetes:$PORT/version" >/dev/null 2>&1 && break
  curl -ks -m 5 "https://127.0.0.1:$PORT/version" >/dev/null 2>&1 && break
  sleep 5
done

echo "acesso ok: kubeconfig=$OUT tunel=127.0.0.1:$PORT -> $CP_IP:6443"
