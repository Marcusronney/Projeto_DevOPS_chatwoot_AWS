# Documentacao do Projeto Chatwoot AWS

Este projeto provisiona e publica uma instalacao do Chatwoot em ambiente `dev` na AWS, usando Terraform, EKS, Helm, Argo CD, External Secrets, RDS PostgreSQL, Redis e S3.

O desenho geral e:

1. A camada `infra` cria a base AWS: rede, cluster EKS, ECR, banco RDS, Redis, bucket S3 e secrets de infraestrutura.
2. A camada `addons/eks` instala recursos dentro do EKS: Metrics Server, AWS Load Balancer Controller, ExternalDNS, External Secrets Operator, Argo CD e permissoes IAM via IRSA.
3. A camada `app/chatwoot` define como o Chatwoot sera sincronizado pelo Argo CD usando o chart Helm oficial e os manifests auxiliares do projeto.

## Estrutura Geral

```text
.
|-- README.md
|-- ANALISE_TERRAFORM.md
|-- Aplicacao chatwoot.ini
|-- old/
`-- terraform/
    `-- chatwoot-dev/
        |-- infra/
        |-- addons/
        |   `-- eks/
        `-- app/
            `-- chatwoot/
                |-- bootstrap/
                `-- chatwoot-db/
```

## Arquivos da Raiz

`README.md`

Arquivo inicial do repositorio. Hoje contem apenas o nome do projeto.

`ANALISE_TERRAFORM.md`

Documento historico com uma analise do estado da infraestrutura em 04/03/2026. Ele ajuda a entender a evolucao do projeto, mas algumas informacoes ja mudaram: atualmente existem manifests para Argo CD, Helm do Chatwoot, External Secrets e jobs de banco.

`Aplicacao chatwoot.ini`

Arquivo de anotacoes/configuracoes relacionadas a aplicacao Chatwoot. Deve ser tratado como material auxiliar de referencia.

`.gitignore`

Define arquivos e pastas que nao devem entrar no Git, especialmente artefatos locais, cache e arquivos sensiveis.

`DOCUMENTACAO_PROJETO.md`

Este arquivo. Documenta a estrutura atual do projeto e a funcao de cada item principal.

## Pasta `terraform/chatwoot-dev/infra`

Esta pasta e responsavel pela infraestrutura base na AWS. O estado remoto dela fica no S3 em `chatwoot/dev/terraform.tfstate`.

`main.tf`

Cria os principais recursos AWS:

- VPC com subnets publicas e privadas.
- NAT Gateway por zona de disponibilidade.
- Cluster EKS e node group gerenciado.
- Repositorio ECR para imagens do Chatwoot.
- Bucket S3 para anexos do Chatwoot.
- Security Groups para RDS e Redis.
- RDS PostgreSQL para o banco principal do Chatwoot.
- Secret no AWS Secrets Manager com credenciais do RDS.
- ElastiCache Redis.

`variables.tf`

Centraliza parametros da infraestrutura, como regiao AWS, nome do projeto, ambiente, CIDR da VPC, tamanho dos nodes EKS, configuracoes do RDS e tipo do Redis.

`outputs.tf`

Exporta valores usados por outras camadas, como VPC ID, subnets, nome e endpoint do EKS, URL do ECR, nome do bucket S3, endpoint do RDS, endpoint do Redis e dados do OIDC provider.

`providers.tf`

Configura os providers Terraform da camada base:

- `aws`, usado para criar recursos na AWS.
- `random`, usado para gerar a senha do banco.

Tambem define tags padrao nos recursos AWS: `Project`, `Env` e `Managed`.

`backend.tf`

Configura o backend remoto do Terraform no S3, com lock em DynamoDB:

- Bucket: `bucketchatwootprojetoaws`
- Key: `chatwoot/dev/terraform.tfstate`
- Tabela DynamoDB: `bucketchatwootlock`

`tfplan`

Arquivo de plano gerado pelo Terraform. E um artefato local de execucao, nao a definicao da infraestrutura.

`terraform`

Provavel binario ou artefato local do Terraform dentro da pasta. Nao faz parte da configuracao declarativa do projeto.

`C:Usersmarcus.ronneyDocumentschatwoot_AWSProjeto_DevOPS_chatwoot_AWS`

Arquivo com nome acidental gerado por algum comando ou redirecionamento. Nao parece ter funcao operacional no projeto.

## Pasta `terraform/chatwoot-dev/addons/eks`

Esta pasta instala componentes dentro do cluster EKS e depende dos outputs da camada `infra`. O estado remoto dela fica no S3 em `chatwoot/dev/eks-addons.tfstate`.

`remote_state.tf`

Le o estado remoto da camada `infra` e transforma outputs importantes em `locals`, como nome do cluster, VPC ID, OIDC provider e bucket de anexos.

`providers.tf`

Declara os providers Terraform usados nesta camada:

- `aws`
- `kubernetes`
- `helm`

`providers-k8s.tf`

Busca os dados do cluster EKS e configura os providers Kubernetes e Helm para aplicar recursos diretamente no cluster.

`backend.tf`

Configura o backend remoto dessa camada no S3, separado da infraestrutura base.

`variables.tf`

Define variaveis especificas dos addons:

- `aws_region`
- `route53_zone_id`
- `externaldns_domain_filters`

`outputs.tf`

Arquivo reservado para expor outputs dos addons. Atualmente nao apresentou saidas relevantes no conteudo lido.

`access.tf`

Cria acesso administrativo ao EKS para o usuario IAM `projeto_chatwoot`, usando `aws_eks_access_entry` e associacao com a policy `AmazonEKSClusterAdminPolicy`.

`addons.tf`

Instala componentes essenciais no cluster:

- Metrics Server, para metricas usadas por HPA e comandos como `kubectl top`.
- AWS Load Balancer Controller, para criar e gerenciar ALBs a partir de Ingress.
- ExternalDNS, para sincronizar registros DNS no Route53.

Tambem cria policies IAM, roles IRSA e service accounts para os controllers.

`argocd.tf`

Cria o namespace `argocd` e instala o Argo CD via Helm. Tambem configura Ingress com ALB para acesso por `argocd.ronney.tech`.

`external_secrets.tf`

Instala o External Secrets Operator e cria a role IRSA que permite ler secrets no AWS Secrets Manager, incluindo:

- `chatwoot/dev/app`
- `chatwoot-dev/rds/postgres`

`chatwoot-irsa.tf`

Cria a policy IAM e a role IRSA da aplicacao Chatwoot para acessar o bucket S3 de anexos. A trust policy aponta para a service account `chatwoot` no namespace `chatwoot`.

`tfplan`

Plano Terraform gerado localmente para essa camada.

`teste.md`

Arquivo auxiliar de teste/anotacao. Nao parece participar do provisionamento.

## Pasta `terraform/chatwoot-dev/app/chatwoot`

Esta pasta contem a configuracao GitOps da aplicacao Chatwoot.

`application.yaml`

Define uma `Application` do Argo CD chamada `chatwoot`. Ela usa duas fontes:

- Chart Helm oficial em `https://chatwoot.github.io/charts`.
- Este repositorio GitHub para buscar o arquivo `values.yaml`.

A aplicacao e instalada no namespace `chatwoot`, com sincronizacao automatica, `prune` e `selfHeal` habilitados.

`values.yaml`

Arquivo de valores do Helm chart do Chatwoot. Ele configura:

- ServiceAccount `chatwoot` com role IRSA.
- Ingress via ALB para `chatwoot.ronney.tech`.
- Certificado ACM para HTTPS.
- ExternalDNS para criar/gerenciar o DNS.
- Uso de RDS externo para PostgreSQL.
- Redis instalado pelo chart, com senha vinda de secret.
- Secret existente `chatwoot-secrets` para variaveis sensiveis.
- Variaveis de ambiente do Chatwoot, como `FRONTEND_URL`, `ACTIVE_STORAGE_SERVICE`, `AWS_REGION`, `S3_BUCKET_NAME` e `PGSSLMODE`.
- Probes de startup, readiness e liveness no endpoint `/health`.

## Pasta `terraform/chatwoot-dev/app/chatwoot/bootstrap`

Esta pasta prepara os recursos minimos que precisam existir antes do chart principal do Chatwoot consumir secrets.

`application.yaml`

Define uma `Application` do Argo CD chamada `chatwoot-bootstrap`, apontando para esta propria pasta. Serve para aplicar namespace, SecretStore e ExternalSecret.

`kustomization.yaml`

Lista os manifests que serao aplicados pelo Kustomize:

- `application.yaml`
- `namespace.yaml`
- `secretstore-chatwoot.yaml`
- `externalsecret-chatwoot.yaml`

`namespace.yaml`

Cria o namespace Kubernetes `chatwoot`.

`secretstore-chatwoot.yaml`

Cria um `SecretStore` do External Secrets apontando para o AWS Secrets Manager na regiao `us-east-1`.

`externalsecret-chatwoot.yaml`

Cria o secret Kubernetes `chatwoot-secrets` a partir do AWS Secrets Manager. Ele busca:

- `SECRET_KEY_BASE` em `chatwoot/dev/app`.
- `REDIS_PASSWORD` em `chatwoot/dev/app`.
- `POSTGRES_PASSWORD` em `chatwoot-dev/rds/postgres`.

## Pasta `terraform/chatwoot-dev/app/chatwoot/chatwoot-db`

Esta pasta contem manifests auxiliares para preparar ou migrar o banco do Chatwoot.

`serviceaccount-chatwoot.yaml`

Cria a service account `chatwoot` no namespace `chatwoot` com anotacao IRSA para assumir a role `chatwoot-dev-chatwoot-irsa`.

`chatwoot-db-migrate.yaml`

Define um Job Kubernetes chamado `chatwoot-db-migrate` que executa:

```text
bundle exec rails db:migrate
```

Ele usa a imagem `chatwoot/chatwoot:v4.11.1`, carrega variaveis diretamente no manifest e tambem importa valores do secret `chatwoot-secrets`.

`chatwoot-db-prepare.yaml`

Tambem define um Job chamado `chatwoot-db-migrate`, mas usando `envFrom` com os secrets `chatwoot-env` e `chatwoot-secrets`. Pelo nome do arquivo, a intencao parece ser preparar o banco, mas o comando atual tambem executa `db:migrate`.

Observacao: os arquivos `chatwoot-db-migrate.yaml` e `chatwoot-db-prepare.yaml` usam o mesmo `metadata.name`. Se aplicados juntos no mesmo namespace, um pode conflitar com o outro.

## Pasta `old`

Pasta de historico e experimentos antigos. Ela contem manifests e arquivos Terraform anteriores, alem de uma copia/cache de `.terraform` em subpastas.

`old/argocd.tf`

Configuracao antiga relacionada ao Argo CD.

`old/chatwoot-bootstrap.tf`

Configuracao antiga para bootstrap do Chatwoot.

`old/secret.yaml`

Manifest antigo de secret. Deve ser revisado com cuidado, pois arquivos de secret podem conter informacoes sensiveis.

`old/cluster/dev/app.yaml`

Manifest antigo de aplicacao para ambiente dev.

`old/cluster/dev/kustomization.yaml`

Kustomization antigo para agrupar manifests do ambiente dev.

`old/.kubernetes/`

Conjunto antigo de manifests Kubernetes, como namespace, secret, service account, repositorio Helm e release Helm.

`old/chatwoot/dev/.terraform/`

Cache local antigo do Terraform, incluindo modulos baixados. Normalmente nao deve ser usado como fonte de verdade do projeto.

## Fluxo de Deploy Esperado

1. Aplicar a camada `terraform/chatwoot-dev/infra` para criar a infraestrutura AWS.
2. Aplicar a camada `terraform/chatwoot-dev/addons/eks` para instalar controllers, External Secrets e Argo CD no EKS.
3. Sincronizar a aplicacao `chatwoot-bootstrap` no Argo CD para criar namespace e secrets.
4. Sincronizar a aplicacao `chatwoot` no Argo CD para instalar o chart Helm do Chatwoot.
5. Executar o Job de migracao/preparo de banco quando necessario.
6. Acessar o Chatwoot pelo host `chatwoot.ronney.tech`, publicado via ALB e DNS no Route53.

## Componentes AWS Criados

VPC e subnets

Base de rede para todos os recursos. As subnets publicas recebem ALB e as privadas hospedam EKS nodes, RDS e Redis.

EKS

Cluster Kubernetes onde rodam Argo CD, controllers e Chatwoot.

ECR

Repositorio para imagens Docker do Chatwoot, caso o projeto use build proprio.

RDS PostgreSQL

Banco principal do Chatwoot. Fica privado e acessivel apenas a partir dos nodes EKS.

ElastiCache Redis

Cache/fila usado pelo Chatwoot. No `values.yaml`, o Redis esta habilitado pelo chart, entao vale decidir se o projeto deve usar o Redis gerenciado da AWS ou o Redis instalado no Kubernetes.

S3

Bucket usado para anexos do Chatwoot, com versionamento, bloqueio de acesso publico e criptografia.

Secrets Manager

Armazena credenciais do RDS e secrets da aplicacao que sao sincronizados para Kubernetes via External Secrets.

Route53 e ACM

Usados para DNS publico e HTTPS dos hosts `chatwoot.ronney.tech` e `argocd.ronney.tech`.

## Pontos de Atencao

- `ANALISE_TERRAFORM.md` parece desatualizado em relacao ao estado atual dos manifests.
- Ha dois Jobs de banco com o mesmo nome `chatwoot-db-migrate`.
- O `values.yaml` usa RDS externo para PostgreSQL, mas habilita Redis interno do chart; isso pode ser intencional, mas deve ser confirmado.
- Existem artefatos locais versionados ou presentes na arvore, como `tfplan`, cache `.terraform`, binario `terraform` e um arquivo com nome acidental.
- Arquivos em `old/` devem ser tratados como historico, nao como fonte principal do deploy.
