# pve02: Kubernetes 1.35 + Rook-Ceph (substitui Longhorn) + discos SO 60 GB

Data: 2026-08-01
Status: aprovado (Erik)
Escopo: rebuild completo do cluster do workspace `pve02` (destroy + apply autorizado; dados atuais de Rancher/ArgoCD/Passbolt do pve02 serão perdidos).

## Objetivo

Recriar o cluster k8s do pve02 com:

1. Kubernetes **v1.35.7** (kubeadm), containerd **2.x**
2. Storage **Rook-Ceph** no lugar do Longhorn — SCs `ceph-block` (RBD, RWO, default) e `ceph-fs` (CephFS, RWX)
3. Discos de SO de **todas** as VMs k8s em **60 GB** (dados dos workers mantém 150 GB → OSD Ceph)

## Contexto atual

- kubeadm `v1.30.0`, Ubuntu 24.04 cloud image, containerd.io `1.7.27-1`, config kubeadm `v1beta3`
- Longhorn via Helm (`modules/k8s-addons/main.tf`) + chart local `charts/longhorn-classes` (SCs `longhorn-fs`/`longhorn-block`)
- Workers: disco SO 60 GB + disco de dados 150 GB (`/dev/sdb`, usado pelo Longhorn)
- Control planes: disco SO 40 GB
- pve02: 3 control planes + 3 workers, host único Proxmox (`pve02-kubepriority`), pool ZFS `data`
- Workspace terraform `pve02` já selecionado; tfvars: `secret.auto-pve02.tfvars`

## Decisões

| Decisão | Escolha | Motivo |
|---|---|---|
| Distribuição Ceph | Rook-Ceph dentro do k8s | pve02 é host Proxmox único; Ceph no host sem redundância real. Rook usa os 3 discos de dados como OSDs, replica 3 — mesmo layout do Longhorn |
| SCs | `ceph-block` (default) + `ceph-fs` | equivale aos dois SCs Longhorn; RWX preservado para quem precisar |
| Discos 60 GB | SO de workers e control planes | dados workers mantém 150 (capacidade Ceph) |
| kubeadm config | `v1beta4` | disponível desde 1.31; v1beta3 deprecado; formato `extraArgs` vira lista name/value |
| containerd | 2.x (repo Docker) | k8s 1.35 é a última versão a suportar 1.x; rebuild do zero, evita retrabalho no 1.36 |

## Mudanças por arquivo

### `modules/proxmox/templates/cloud-config.yaml.tftpl`

- Repo apt k8s `v1.30` → `v1.35`; `kubelet=kubeadm=kubectl=1.35.7-1.1`; `kubernetesVersion: v1.35.7`
- `apiVersion: kubeadm.k8s.io/v1beta3` → `v1beta4` em ClusterConfiguration/InitConfiguration (ajustar formato de campos que mudaram)
- `containerd.io=1.7.27-1` → `containerd.io=2.2.6-1~ubuntu.24.04~noble`; manter `containerd config default` + sed `SystemdCgroup = true` (chave igual no config v3)
- Remover `open-iscsi`/`nfs-common` e `systemctl enable iscsid` (Longhorn-only); adicionar `lvm2` (requisito Rook OSD)
- Garantir que `/dev/sdb` dos workers fica **raw** (sem mkfs/mount) — Rook exige disco cru

### `secret.auto-pve02.tfvars`

- `control_plane_os_disk_size = 60`
- `storage_backend = "ceph"`, `storage_replicas = 3` (comentários de storage atualizados)

### `variables.tf` + `modules/k8s-addons/variables.tf` + `secret.auto.tfvars.example`

**Correção pós-aprovação (compartilhamento com pve01):** o código é usado pelos dois
workspaces; remover Longhorn do módulo desinstalaria o Longhorn do pve01 no próximo
apply, violando o "fora de escopo". Em vez de remover:

- Nova var `storage_backend` (`"longhorn"` | `"ceph"`, default `"longhorn"`) escolhe o
  backend por workspace — controla pacotes/format do cloud-init e qual conjunto de
  helm releases instala. `enable_longhorn` deixa de existir (derivado do backend).
- `longhorn_replicas` → `storage_replicas` (vale para os dois backends)
- `longhorn_datastore_name` → `data_disk_datastore_name` (neutro)
- `secret.auto-pve01.tfvars` só troca nomes de chaves (sem mudança de infra)
- `charts/longhorn-classes` **permanece** no repo (usado pelo pve01)

### `modules/k8s-addons/main.tf`

- `helm_release.longhorn` e `helm_release.longhorn_classes` passam a condicionar em
  `var.storage_backend == "longhorn"` (pve01 continua com Longhorn)
- Adicionar (condicionado a `var.storage_backend == "ceph"`, Rook v1.20.3):
  - `helm_release.rook_ceph` (operator, repo `https://charts.rook.io/release`, ns `rook-ceph`)
  - `helm_release.rook_ceph_cluster` (chart `rook-ceph-cluster`): CephCluster com 3 mons, OSDs via filtro de device `sdb` nos workers, `replicated.size = var.ceph_replicas`, toolbox habilitado, dashboard desabilitado
  - SCs pelo values do cluster chart: `ceph-block` (RBD, default) e `ceph-fs` (CephFS, MDS ativo + standby)
- Dependências de `passbolt`/demais releases que apontavam para `longhorn_classes` passam a apontar para `rook_ceph_cluster`

### `modules/proxmox/templates/cloud-config.yaml.tftpl` (storage condicional)

- Blocos `disk_setup`/`fs_setup`/`mounts` do `/dev/vdb` e pacotes `open-iscsi`/
  `nfs-common` só quando `storage_backend == "longhorn"`; `lvm2` e vdb raw quando
  `"ceph"` (flag chega ao template via módulo proxmox)

## Execução

1. Workspace `pve02` ativo, var-file `secret.auto-pve02.tfvars`
2. `terraform destroy` (autorizado)
3. `terraform apply`
4. Validação:
   - `kubectl get nodes` → 6 nodes `v1.35.7` Ready
   - Toolbox: `ceph status` → `HEALTH_OK`, 3 OSDs up/in
   - `kubectl get sc` → `ceph-block` (default) e `ceph-fs`
   - PVC de teste RWO em `ceph-block` e RWX em `ceph-fs` → ambos `Bound`
   - Rancher/ArgoCD/Passbolt no ar com PVCs em `ceph-block`

## Fora de escopo

- pve01 (workspace default) — intocado
- Migração de dados Longhorn → Ceph (destroy autorizado)
- Ceph dashboard, monitoramento Prometheus do Ceph
