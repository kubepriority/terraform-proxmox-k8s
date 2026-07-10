# Design: Bootstrap de addons Kubernetes via Terraform + Helm

Data: 2026-07-09
Status: aprovado

## Contexto

Cluster k8s (kubeadm v1.30, Calico) roda em VMs Proxmox num servidor dedicado OVH.
IP público `139.99.62.36` fica no host Proxmox; VMs em rede privada `10.10.10.0/24`
(control plane `10.10.10.50`). Cluster recém-criado: sem MetalLB, cert-manager ou
ingress. Manifests manuais da pasta `kubernetes/` (cert-manager DNS-01 via Google
Cloud DNS, certificado wildcard `*.kubepriority.com.br`) serão convertidos para
Terraform. OVH Load Balancer (produto) descartado: exigiria vRack, sem ganho com
um único servidor.

## Decisões

- **Entrada de tráfego:** MetalLB (L2) + DNAT no host Proxmox. VIP fixo do
  ingress-nginx: `10.10.10.100`; pool `10.10.10.100-10.10.10.110` (VMs usam faixa
  a partir de `.50`).
- **Custom resources via charts locais:** ClusterIssuer, Certificate,
  IPAddressPool e L2Advertisement são CRDs — o provider helm não aplica YAML
  solto e `kubernetes_manifest` exige CRDs no plan. Solução: dois mini-charts
  locais no repo, aplicados por `helm_release` em apply-time. Um único
  `terraform apply` resolve tudo.
- **Wildcard como default:** ingress-nginx com
  `--default-ssl-certificate=ingress-nginx/ingress-nginx-tls`; qualquer Ingress
  com TLS usa o wildcard sem repetir `secretName`.
- **Observabilidade removida:** `modules/helm` (metrics-server,
  kube-prometheus-stack) deletado; usuário não vai usar.
- **E-mail ACME:** `hudson.erik@gmail.com` (substitui e-mail corporativo do YAML
  antigo).
- **Execução remota:** cluster inacessível da máquina de desenvolvimento;
  `terraform apply` roda na máquina `architect` via túnel SSH até a API do
  cluster.

## Estrutura de arquivos

```text
charts/
  metallb-config/      # IPAddressPool + L2Advertisement
  cert-infra/          # Secret GCP + ClusterIssuer + Certificate wildcard
modules/
  k8s-addons/          # novo módulo: 5 helm_release
scripts/
  get-kubeconfig.sh    # busca kubeconfig via SSH jump + reescreve server
  proxmox-dnat.sh      # DNAT 80/443 no host Proxmox (rodado manualmente)
docs/superpowers/specs/  # este documento
```

Removidos: `modules/helm`, bloco comentado em `main.tf` (linhas 31-45), provider
helm EKS comentado em `provider.tf`, YAMLs de `kubernetes/` convertidos em
templates (`cluster-issuer-prod.yaml` http01 legado também sai; README da pasta
fica como documentação do setup GCP).

## Módulo `k8s-addons`

Cadeia de dependências (`depends_on`):

```text
helm_release.metallb            (repo metallb.github.io/metallb, ns metallb-system)
  └─ helm_release.metallb_config  (chart local charts/metallb-config)
       └─ helm_release.ingress_nginx (repo kubernetes.github.io/ingress-nginx,
            ns ingress-nginx, annotation metallb.io/loadBalancerIPs=<vip>,
            extraArgs.default-ssl-certificate)
helm_release.cert_manager       (repo charts.jetstack.io, ns cert-manager,
                                 crds.enabled=true)
  └─ helm_release.cert_infra      (chart local charts/cert-infra; depende também
       de ingress_nginx, pois o Certificate mora no ns ingress-nginx)
```

Conteúdo dos charts locais:

- `metallb-config`: `IPAddressPool` (faixa via values) e `L2Advertisement`.
- `cert-infra`: `Secret clouddns-dns01-credentials` (key.json via values
  sensitive), `ClusterIssuer letsencrypt-dns01-prd` (ACME DNS-01 cloudDNS),
  `Certificate ingress-nginx-tls` (`*.kubepriority.com.br` +
  `kubepriority.com.br`, secret `ingress-nginx-tls` no ns `ingress-nginx`).

Variáveis do módulo:

| Variável | Default | Descrição |
|---|---|---|
| `metallb_pool` | `10.10.10.100-10.10.10.110` | Faixa do IPAddressPool |
| `ingress_vip` | `10.10.10.100` | VIP fixo do Service do ingress-nginx |
| `acme_email` | `hudson.erik@gmail.com` | E-mail da conta ACME |
| `gcp_project` | `project-90293a0a-5d49-4604-a23` | Projeto do Cloud DNS |
| `gcp_sa_key_path` | — (sensitive) | Caminho local do JSON da service account |
| `domain` | `kubepriority.com.br` | Domínio base do wildcard |

Provider `helm` declarado no root (`provider.tf`) com
`kubernetes { config_path = var.kubeconfig_path }`.

## Fluxo de aplicação (máquina architect)

1. `scripts/get-kubeconfig.sh` — `scp -J root@139.99.62.36
   ubuntu@10.10.10.50:~/.kube/config`, reescreve `server:
   https://127.0.0.1:6443` e adiciona `tls-server-name: kubernetes`; salva
   `./kubeconfig` (gitignored).
2. Túnel: `ssh -fN -L 6443:10.10.10.50:6443 root@139.99.62.36`.
3. `terraform apply`.
4. No host Proxmox: `scripts/proxmox-dnat.sh` — iptables DNAT `80/443 →
   10.10.10.100` + FORWARD + persistência.
5. DNS no Cloud DNS (manual): `A *.kubepriority.com.br` e
   `A kubepriority.com.br` → `139.99.62.36`.
6. Validação: `kubectl -n ingress-nginx get certificate` até `Ready: True`
   (emissão DNS-01 leva minutos); depois
   `curl -v https://qualquer.kubepriority.com.br`.

## Tratamento de erros

- Emissão de certificado é assíncrona: `helm_release.cert_infra` conclui antes
  do certificado ficar Ready. Validação via kubectl documentada; sem wait no
  Terraform.
- Rate limit Let's Encrypt: 5 certificados/semana por conjunto de domínios —
  sem retry automático; troubleshooting via `kubectl get challenges -A`.
- Timeouts dos `helm_release` ficam nos defaults (5 min), suficientes para
  charts pequenos.

## Segurança

- `cert-manager-dns01.json` (chave real de service account GCP com
  `roles/dns.admin`) está no repo sem estar no `.gitignore` e a pasta ainda não
  foi commitada. Ação: adicionar `kubernetes/lets-encrypt-dns-google/*.json` e
  `kubeconfig` ao `.gitignore` antes de qualquer commit da pasta.
- Caminho da chave via `secret.auto.tfvars` (já ignorado). Conteúdo entra no
  state; state é local e gitignored.
- Se o repositório for público ou compartilhado, rotacionar a chave.

## Fora de escopo

- Observabilidade (metrics-server, Prometheus, Grafana) — removida.
- Storage class (OpenEBS) — etapa futura.
- Automação do DNAT e do DNS público — passos manuais documentados.

## Adendo (mesmo dia, pós-implementação)

- **Rancher 2.13.3** adicionado ao módulo (`helm_release.rancher`, ns
  `cattle-system`, 1 réplica, hostname `rancher.<domain>`). TLS próprio via
  annotation `cert-manager.io/cluster-issuer` (ingress-shim emite
  `tls-rancher-ingress`). Bootstrap password em `secret.auto.tfvars`.
- **Bootstrap automatizado** (`bootstrap.tf`) substituiu os passos manuais:
  `cluster_access` (kubeconfig via `qm guest exec` + túnel 6443, roda todo
  apply), `proxmox_dnat` (remote-exec idempotente) e `public_dns` (upsert
  gcloud). IPs derivados de `proxmox_endpoint`/`proxmox_network_prefix`;
  ambiente novo = copiar `secret.auto.tfvars` + key.json e rodar um único
  `terraform apply`. Scripts `get-kubeconfig.sh`/`proxmox-dnat.sh` removidos
  em favor de `ensure-access.sh`/`update-dns.sh`.
