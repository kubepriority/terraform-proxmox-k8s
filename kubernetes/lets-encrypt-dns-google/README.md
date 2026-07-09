# Configuração do Let's Encrypt com Google Cloud DNS e Cert-Manager

Este guia descreve como configurar o **Cert-Manager** no Kubernetes para emitir certificados SSL/TLS do **Let's Encrypt** utilizando o **Google Cloud DNS** como provedor DNS para validação DNS-01.

## Arquitetura

```text
Let's Encrypt
      |
      v
Cert-Manager
      |
      v
Google Cloud DNS
      |
      v
Zona DNS: kubepriority.com.br
```

## Pré-requisitos

1. Cluster Kubernetes com Cert-Manager instalado.
2. Zona DNS criada no Google Cloud DNS.
3. Domínio apontando para os Name Servers do Cloud DNS.
4. Permissões para criar registros DNS na zona.
5. Projeto GCP com Billing ativo.

---

## 1. Criar Service Account

```bash
export PROJECT_ID="project-90293a0a-5d49-4604-a23"

gcloud iam service-accounts create cert-manager-dns01 \
  --project $PROJECT_ID \
  --display-name "cert-manager DNS01"
```

Conceder permissão de DNS Admin:

```bash
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:cert-manager-dns01@$PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/dns.admin"
```

---

## 2. Habilitar Criação de Chaves (se bloqueado)

Caso exista a policy:

```text
constraints/iam.disableServiceAccountKeyCreation
```

Verificar:

```bash
gcloud org-policies describe constraints/iam.disableServiceAccountKeyCreation \
  --organization=401537555346
```

Criar:

```yaml
name: organizations/401537555346/policies/iam.disableServiceAccountKeyCreation
spec:
  rules:
  - enforce: false
```

Aplicar:

```bash
gcloud org-policies set-policy disable-key-policy.yaml
```

Aguardar a propagação da policy.

---

## 3. Criar a Chave JSON

```bash
gcloud iam service-accounts keys create cert-manager-dns01.json \
  --iam-account="cert-manager-dns01@project-90293a0a-5d49-4604-a23.iam.gserviceaccount.com" \
  --project project-90293a0a-5d49-4604-a23
```

---

## 4. Criar Secret no Kubernetes

```bash
kubectl -n cert-manager create secret generic clouddns-dns01-credentials \
  --from-file=key.json=cert-manager-dns01.json
```

Validar:

```bash
kubectl get secret clouddns-dns01-credentials -n cert-manager
```

---

## 5. Criar ClusterIssuer

Arquivo: `cluster-issuer-prd.yaml`

```yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-dns01-prd
spec:
  acme:
    email: henderson.andrade@caixaconsorcio.com.br
    server: https://acme-v02.api.letsencrypt.org/directory
    privateKeySecretRef:
      name: letsencrypt-dns01-prd-private-key
    solvers:
    - dns01:
        cloudDNS:
          project: project-90293a0a-5d49-4604-a23
          serviceAccountSecretRef:
            name: clouddns-dns01-credentials
            key: key.json
```

Aplicar:

```bash
kubectl apply -f cluster-issuer-prd.yaml
```

Validar:

```bash
kubectl describe clusterissuer letsencrypt-dns01-prd
```

Status esperado:

```text
Type: Ready
Status: True
Reason: ACMEAccountRegistered
```

---

## 6. Solicitar Certificado Wildcard

Arquivo: `certificate-nginx-ingress-prd.yaml`

```yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: ingress-nginx-tls
  namespace: ingress-nginx
spec:
  secretName: ingress-nginx-tls
  issuerRef:
    name: letsencrypt-dns01-prd
    kind: ClusterIssuer
  dnsNames:
    - "*.kubepriority.com.br"
    - "kubepriority.com.br"
```

Aplicar:

```bash
kubectl apply -f certificate-nginx-ingress-prd.yaml
```

---

## 7. Monitorar Emissão

```bash
kubectl get orders -A
kubectl get challenges -A
```

Detalhar:

```bash
kubectl -n ingress-nginx describe certificate ingress-nginx-tls
```

Verificar TXT criado:

```bash
gcloud dns record-sets list \
  --zone=kubepriority-zone \
  --name="_acme-challenge.kubepriority.com.br." \
  --type=TXT
```

---

## 8. Validar Certificado

```bash
kubectl -n ingress-nginx get secret ingress-nginx-tls
```

Verificar:

```bash
kubectl -n ingress-nginx describe certificate ingress-nginx-tls
```

Status esperado:

```text
Ready: True
```

---

## 9. Utilizar no NGINX Ingress

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: grafana
  namespace: observability
spec:
  ingressClassName: nginx

  tls:
  - hosts:
    - grafana.kubepriority.com.br
    secretName: ingress-nginx-tls

  rules:
  - host: grafana.kubepriority.com.br
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: grafana
            port:
              number: 80
```

---

## Comandos de Troubleshooting

```bash
kubectl get certificaterequests -A
kubectl get orders -A
kubectl get challenges -A

kubectl describe clusterissuer letsencrypt-dns01-prd

kubectl -n ingress-nginx describe certificate ingress-nginx-tls

kubectl logs -n cert-manager deploy/cert-manager
```

## Resultado Final

- Certificado Wildcard emitido pelo Let's Encrypt
- Renovação automática pelo Cert-Manager
- DNS-01 utilizando Google Cloud DNS
- Compatível com NGINX Ingress Controller
- Cobertura para `*.kubepriority.com.br`
