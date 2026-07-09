#!/usr/bin/env bash
# Roda NO HOST PROXMOX (root). Encaminha 80/443 do IP publico para o VIP do
# ingress-nginx (MetalLB). Idempotente: -C testa antes de -A.
set -euo pipefail

PUBLIC_IP="139.99.62.36"
INGRESS_VIP="10.10.10.100"

sysctl -w net.ipv4.ip_forward=1 >/dev/null

for PORT in 80 443; do
  iptables -t nat -C PREROUTING -d "$PUBLIC_IP" -p tcp --dport "$PORT" \
    -j DNAT --to-destination "$INGRESS_VIP:$PORT" 2>/dev/null ||
    iptables -t nat -A PREROUTING -d "$PUBLIC_IP" -p tcp --dport "$PORT" \
      -j DNAT --to-destination "$INGRESS_VIP:$PORT"

  iptables -C FORWARD -d "$INGRESS_VIP" -p tcp --dport "$PORT" -j ACCEPT 2>/dev/null ||
    iptables -A FORWARD -d "$INGRESS_VIP" -p tcp --dport "$PORT" -j ACCEPT
done

# Persistencia entre reboots
if command -v netfilter-persistent >/dev/null; then
  netfilter-persistent save
else
  echo "AVISO: instale iptables-persistent para persistir as regras:"
  echo "  apt-get install -y iptables-persistent && netfilter-persistent save"
fi

echo "DNAT ativo: $PUBLIC_IP:80/443 -> $INGRESS_VIP"
