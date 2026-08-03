# Passbolt: cadastro restrito ao dominio

O auto-cadastro do Passbolt tem dois niveis:

1. `PASSBOLT_REGISTRATION_PUBLIC` (env, via `passbolt_public_registration` no tfvars)
   — `true` abre cadastro para qualquer e-mail da internet. Mantemos `false`.
2. Plugin **Self Registration** — allowlist de dominios, guardada no **banco**, nao
   em env nem no Helm. Com ela configurada o cadastro funciona mesmo com o item 1
   em `false`, aceitando so os dominios listados.

Como a allowlist vive no banco, ela **se perde se o banco for recriado** (ex.: trocar
`passbolt_ha`, que renomeia o StatefulSet do mariadb). O caminho suportado e a UI:
Administration > Self Registration. Para reaplicar direto no banco:

```sql
-- property_id = uuid5('d5447ca1-950f-459d-8b20-86ddfdd0f922',
--                     'organization.settings.property.id.selfRegistration')
INSERT INTO organization_settings (id, property_id, property, value, created, modified, created_by, modified_by)
SELECT uuid(), '3ed5c2fe-f731-556a-97d0-301142e223ab', 'selfRegistration',
       '{"provider":"email_domains","data":{"allowed_domains":["kubepriority.com.br"]}}',
       now(), now(), id, id
FROM users WHERE username = 'erik.marques@kubepriority.com.br' LIMIT 1;
```

Detalhes que custaram tempo e nao sao obvios:

- `property_id` NAO e o hash do nome da propriedade: e
  `uuid5(PASSBOLT_SEED, 'organization.settings.property.id.' + propriedade)`
  (`OrganizationSetting::UUID_NAMESPACE`). A linha `edition` que ja existe no banco
  usa outro esquema e induz ao erro.
- O JSON exige `allowed_domains` aninhado em `data`; sem isso o passbolt responde
  "Could not validate the self registration settings found in database".

Validacao (o endpoint de dry-run diz se um e-mail poderia se cadastrar):

```bash
curl -s -c /tmp/c -o /dev/null -L https://passbolt.<dominio>/register
T=$(grep -i csrf /tmp/c | awk '{print $7}')
curl -s -b /tmp/c -X POST -H 'Content-Type: application/json' -H "X-CSRF-Token: $T" \
  -d '{"email":"alguem@kubepriority.com.br"}' \
  https://passbolt.<dominio>/self-registration/dry-run.json   # success
curl -s -b /tmp/c -X POST -H 'Content-Type: application/json' -H "X-CSRF-Token: $T" \
  -d '{"email":"alguem@gmail.com"}' \
  https://passbolt.<dominio>/self-registration/dry-run.json   # error
```

Primeiro admin (o cadastro por convite depende de existir um):

```bash
kubectl -n passbolt exec deploy/passbolt-depl-srv -c passbolt -- \
  su -s /bin/bash -c "/usr/share/php/passbolt/bin/cake passbolt register_user \
  -u <email> -f <nome> -l <sobrenome> -r admin" www-data
```
