#!/usr/bin/env bash
# Configura WireGuard no host Proxmox (roadwarrior + site-to-site opcional).
# Idempotente: chaves geradas uma unica vez; wg0.conf remontado a cada execucao.
# Chamado pelo Terraform (null_resource.wireguard). Manual:
#   PUBLIC_HOST=1.2.3.4 SSH_PASSWORD=... VPN_CIDR=10.20.0.0/24 \
#   VPN_CLIENTS="erik notebook2" INTERNAL_CIDR=10.10.10.0/24 ./scripts/setup-wireguard.sh
set -euo pipefail

: "${PUBLIC_HOST:?}" "${SSH_PASSWORD:?}" "${VPN_CIDR:?}" "${INTERNAL_CIDR:?}"
VPN_CLIENTS="${VPN_CLIENTS:-}"
SITE_PEER_PUBLIC_KEY="${SITE_PEER_PUBLIC_KEY:-}"
SITE_REMOTE_CIDR="${SITE_REMOTE_CIDR:-}"
VPN_PORT="${VPN_PORT:-51820}"
OUT_DIR="${OUT_DIR:-./vpn}"

export SSHPASS="$SSH_PASSWORD"
SSH_OPTS=(-o StrictHostKeyChecking=accept-new -o ConnectTimeout=15)
run() { sshpass -e ssh "${SSH_OPTS[@]}" "root@$PUBLIC_HOST" "$@"; }

VPN_BASE="${VPN_CIDR%.*}" # 10.20.0.0/24 -> 10.20.0
VPN_BASE="${VPN_BASE%/*}"
SERVER_IP="${VPN_BASE}.1"

run "DEBIAN_FRONTEND=noninteractive apt-get install -y wireguard >/dev/null 2>&1 || true
mkdir -p /etc/wireguard/clients && chmod 700 /etc/wireguard
[ -f /etc/wireguard/server.key ] || { umask 077; wg genkey | tee /etc/wireguard/server.key | wg pubkey > /etc/wireguard/server.pub; }"

SERVER_PUB=$(run "cat /etc/wireguard/server.pub")

# Chaves por cliente (geradas uma vez) e montagem do wg0.conf
CONF="[Interface]
Address = $SERVER_IP/${VPN_CIDR#*/}
ListenPort = $VPN_PORT
PrivateKey = __SERVER_KEY__
PostUp = iptables -A FORWARD -i wg0 -j ACCEPT; iptables -A FORWARD -o wg0 -j ACCEPT
PostDown = iptables -D FORWARD -i wg0 -j ACCEPT; iptables -D FORWARD -o wg0 -j ACCEPT
"

mkdir -p "$OUT_DIR"
IDX=10
for NAME in $VPN_CLIENTS; do
  CLIENT_IP="${VPN_BASE}.${IDX}"
  run "[ -f /etc/wireguard/clients/$NAME.key ] || { umask 077; wg genkey | tee /etc/wireguard/clients/$NAME.key | wg pubkey > /etc/wireguard/clients/$NAME.pub; }"
  CLIENT_PUB=$(run "cat /etc/wireguard/clients/$NAME.pub")
  CLIENT_KEY=$(run "cat /etc/wireguard/clients/$NAME.key")

  CONF+="
[Peer]
# cliente: $NAME
PublicKey = $CLIENT_PUB
AllowedIPs = $CLIENT_IP/32
"

  cat > "$OUT_DIR/$NAME.conf" <<EOF
[Interface]
PrivateKey = $CLIENT_KEY
Address = $CLIENT_IP/${VPN_CIDR#*/}
DNS = ${INTERNAL_CIDR%.*/*}.3

[Peer]
PublicKey = $SERVER_PUB
Endpoint = $PUBLIC_HOST:$VPN_PORT
AllowedIPs = $INTERNAL_CIDR, $VPN_CIDR
PersistentKeepalive = 25
EOF
  chmod 600 "$OUT_DIR/$NAME.conf"
  IDX=$((IDX + 1))
done

if [ -n "$SITE_PEER_PUBLIC_KEY" ] && [ -n "$SITE_REMOTE_CIDR" ]; then
  CONF+="
[Peer]
# site-to-site on-premise
PublicKey = $SITE_PEER_PUBLIC_KEY
AllowedIPs = $SITE_REMOTE_CIDR
PersistentKeepalive = 25
"
fi

run "cat > /etc/wireguard/wg0.tmpl <<'WGEOF'
$CONF
WGEOF
sed \"s|__SERVER_KEY__|\$(cat /etc/wireguard/server.key)|\" /etc/wireguard/wg0.tmpl > /etc/wireguard/wg0.conf
rm -f /etc/wireguard/wg0.tmpl
chmod 600 /etc/wireguard/wg0.conf
systemctl enable wg-quick@wg0 >/dev/null 2>&1
if systemctl is-active --quiet wg-quick@wg0; then
  wg syncconf wg0 <(wg-quick strip wg0)
else
  systemctl start wg-quick@wg0
fi
wg show wg0 | head -4"

echo "---"
echo "WireGuard ok. Chave publica do server (para o peer on-premise):"
echo "  $SERVER_PUB"
echo "Endpoint: $PUBLIC_HOST:$VPN_PORT"
echo "Configs de cliente em: $OUT_DIR/"
