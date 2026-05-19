
# Arquitetura e Fluxo de Deploy — Chatwoot na AWS (EKS + Terraform + ArgoCD + Grafana + Prometheus)

## Visão Geral

Este projeto demostra como implementar a aplicação **Chatwoot** na AWS utilizando:

- Terraform para provisionamento de infraestrutura
- Amazon EKS para execução da aplicação
- Amazon RDS PostgreSQL como banco de dados externo
- AWS Secrets Manager com External Secrets Operator
- ArgoCD para GitOps
- Helm Chart oficial do Chatwoot
- AWS Load Balancer Controller para exposição via ALB
- AWS Certificate Manager para HTTPS
- Hostinger para gerenciamento DNS

A arquitetura está organizada em três camadas principais:

1. Infraestrutura AWS
2. Addons do cluster Kubernetes
3. Aplicação Chatwoot via GitOps com ArgoCD

![Diagrama](imagens/diagrama.png)

---

# Estrutura da infraestrutura

```
terraform/chatwoot-dev/infra
terraform/chatwoot-dev/addons/eks
aplicação/chatwoot
```

Cada diretório possui responsabilidades específicas dentro do fluxo de
deploy.

```jsx
terraform/
├── chatwoot-dev/                    # Ambiente de desenvolvimento
│   ├── infra/                       # Infraestrutura
│   │   ├── main.tf                  # Cria as VPC, EKS, RDS, Redis, S3, ECR, Secret
│   │   ├── variables.tf             # Variáveis de Nome, CIDR VPC, Especificações do Node, RDS e Redis.
│   │   ├── outputs.tf               # Valores exportados da VPC, Subnets, endpoint, ECR, Bucket S3, RDS, OIDC e Redis.
│   │   ├── providers.tf             # AWS provider
│   │   ├── backend.tf               # Cria a Tabela do backend remoto do Terraform no S3 usando lock no DynamoDB
│   │   └── terraform.tfvars         # Arquivos de Plano Gerados pelo Terraform.
│   │
│   ├── addons/eks/                  # Addons do Kubernetes, Instala componentes dentro do Cluster EKS. 
│   │   ├── addons.tf                # Instala Load Balancer, ExternalDNS, ArgoCD, Metrics Server e cria policies IAM, roles IRSA e service accounts para os controllers.
│   │   ├── argocd.tf                # Configuração ArgoCD, como namespace, ingress com ALB para acesso por "argocd.ronney.tech".
│   │   ├── access.tf                # IAM Access Entry, Cria acessos ADM ao EKS para o usuário("projeto_chatwoot"), ele é associado a policy`AmazonEKSClusterAdminPolicy` usando `aws_eks_access_entry`.
│   │   ├── backend.tf               # Configura o backend remoto dessa camada direto no S3
│   │   ├── providers.tf             # Kubernetes + Helm providers
│   │   ├── providers-k8s.tf         # Declara os Providers usados nas camada "Aws", "K8s" e "helm"
│   │   ├── remote_state.tf          # Le o estado remoto da camada `infra` e transforma outputs importantes em `locals`, como nome do cluster, VPC ID, OIDC provider e bucket de anexos.
│   │   ├── external_secrets.tf      # Instala o External Secrets Operator e cria a Role IRSA que permite ler os secrets dentro do AWS Secrets Manager.
│   │   ├── chatwoot-irsa.tf         # Cria a policy IAM e a Role IRSA da aplicação Chatwoot para acessar o bucket S3. A Trust Policy aponta para a service account "chatwoot" dentro da namespace "chatwoot".
│   │   ├── output.tf                # Expoe os outputs dos Addons.
│   │   └── variables.tf             # Variáveis dos addons
│   │
│   └── aplicação/chatwoot/          # Configuração Chatwoot
│       ├── application.yaml         # Busca os Charts Helm oficial e usa o Values.yaml do repositório.
│       └── values.yaml              # Helm chart values, Define: ServiceAccount, Ingress ALB, Certificados ACM HTTPS, ExternalDNS, RDS, Redis, Secrets, variaveis de ambientes e probes dos pods.
│
│──────── aplicação/chatwoot/bootstrap      # Esta pasta prepara os recursos minimos que precisam existir antes do chart principal do Chatwoot consumir secrets.
│         ├── application.yaml              # GitOPS, cria um Application,
│         ├── values.yaml                   # Helm chart values, Define: ServiceAccount, Ingress ALB, Certificados ACM HTTPS, ExternalDNS, RDS, Redis, Secrets, variaveis de ambientes e probes dos pods.
│         ├── secret.yaml                   # Cria um `SecretStore` do External Secrets apontando para o AWS Secrets Manager na regiao `us-east-1`.
│         ├── namespace.yaml                # Cria o Namespace chatwoot
│         ├── externalsecret-chatwoot.yaml  # Cria o secret Kubernetes `chatwoot-secrets` a partir do AWS Secrets Manager.
│         └── kustomization.yaml            # Lista os manifest que serão aplicados.
│
│──────── aplicação/chatwoot/chatwoot-db    # Banco Chatwoot
│         ├── serviceaccount-chatwoot.yaml  # Cria a service account `chatwoot` no namespace `chatwoot` com anotacao IRSA para assumir a role `chatwoot-dev-chatwoot-irsa`.
│         ├── chatwoot-db-prepare.yaml      # 
│         └── chatwoot-db-migrate.yaml      # Helm chart values, Define: ServiceAccount, Ingress ALB, Certificados ACM HTTPS, ExternalDNS, RDS, Redis, Secrets, variaveis de ambientes e probes dos pods.

```

---


## Stacks do Projeto

###  AWS / AWS
![AWS](https://img.shields.io/badge/AWS-232F3E?style=for-the-badge&logo=amazonwebservices&logoColor=white)
![Amazon EKS](https://img.shields.io/badge/Amazon%20EKS-FF9900?style=for-the-badge&logo=amazoneks&logoColor=white)
![Amazon RDS](https://img.shields.io/badge/Amazon%20RDS-527FFF?style=for-the-badge&logo=amazonrds&logoColor=white)
![Amazon S3](https://img.shields.io/badge/Amazon%20S3-569A31?style=for-the-badge&logo=amazons3&logoColor=white)
![AWS Secrets Manager](https://img.shields.io/badge/AWS%20Secrets%20Manager-DD344C?style=for-the-badge&logo=amazonwebservices&logoColor=white)
![AWS Certificate Manager](https://img.shields.io/badge/AWS%20Certificate%20Manager-FF9900?style=for-the-badge&logo=amazonwebservices&logoColor=white)
![Ingress](https://img.shields.io/badge/Ingress-009639?style=for-the-badge&logo=kubernetes&logoColor=white)
![Hostinger](https://img.shields.io/badge/Hostinger-673DE6?style=for-the-badge&logo=hostinger&logoColor=white)


###  IaC / GitOps
![Terraform](https://img.shields.io/badge/Terraform-844FBA?style=for-the-badge&logo=terraform&logoColor=white)
![ArgoCD](https://img.shields.io/badge/ArgoCD-EF7B4D?style=for-the-badge&logo=argo&logoColor=white)
![Helm](https://img.shields.io/badge/Helm-0F1689?style=for-the-badge&logo=helm&logoColor=white)
![GitHub](https://img.shields.io/badge/GitHub-181717?style=for-the-badge&logo=github&logoColor=white)

### Containers e Orquestração
![Docker](https://img.shields.io/badge/Docker-2496ED?style=for-the-badge&logo=docker&logoColor=white)
![Kubernetes](https://img.shields.io/badge/Kubernetes-326CE5?style=for-the-badge&logo=kubernetes&logoColor=white)

### Banco e Cache
![PostgreSQL](https://img.shields.io/badge/PostgreSQL-4169E1?style=for-the-badge&logo=postgresql&logoColor=white)
![Redis](https://img.shields.io/badge/Redis-DC382D?style=for-the-badge&logo=redis&logoColor=white)

### Segurança e Integrações
![External Secrets](https://img.shields.io/badge/External%20Secrets-3C7DD9?style=for-the-badge&logo=kubernetes&logoColor=white)
![IRSA](https://img.shields.io/badge/IRSA-AWS-orange?style=for-the-badge)
![AWS Load Balancer Controller](https://img.shields.io/badge/AWS%20Load%20Balancer%20Controller-FF9900?style=for-the-badge&logo=amazonwebservices&logoColor=white)



# Fluxo de criação de recursos

```
Terraform Infra
    ↓
Cluster EKS
    ↓
Terraform Addons
    ↓
Metrics Server
ALB Controller
ExternalDNS
ArgoCD
    ↓
ArgoCD GitOps
    ↓
Helm Chart Chatwoot
    ↓
Deployment + Service + Ingress
    ↓
ALB criado automaticamente
    ↓
DNS Publico
```

---

# Resultado Final

A aplicação Chatwoot ficará disponível em:

```
https://chatwoot.ronney.tech
```


---
## Backend Remoto do Terraform com S3 e DynamoDB

Antes de executar a pipeline ou rodar o Terraform, é necessário criar o **backend remoto do Terraform**.

Eu defini o backend remoto composto por:

```
Amazon S3       : armazena o arquivo terraform.tfstate
Amazon DynamoDB : controla o lock de execução do Terraform
```

Estou usando o S3 para armazenar o State do Terraform pois ao executar a pipeline, o terraform cria um arquivo chamado **terraform.tfstate** para armazenar o estado atual da infraestrutura. Esse arquivo irá mapaear o código do terraform com os recursos criados na AWS, como VPC, EKS,RDS, S3, IAM Roles, Secrets, Security Groups, LB, etc.



Bucket: bucketchatwootprojetoaws 
```
aws s3api create-bucket \
  --bucket bucketchatwootprojetoaws \
  --region us-east-1

```

![image.png](imagens/image%201.png)

Bucket para Versionamento

```
aws s3api put-bucket-versioning \
  --bucket bucketchatwootprojetoaws \
  --versioning-configuration Status=Enabled
```

![image.png](imagens/image%202.png)

O versionamento é importante porque permite recuperar versões anteriores do state em caso de erro, exclusão acidental ou corrupção.

DynamoDB

```
aws dynamodb create-table \
  --table-name bucketchatwootlock \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST
```

![image.png](imagens/image%203.png)

Verificando Status da Tabela do Dynamodb. A coluna LockID é usada pelo Terraform para controlar o lock.

```jsx
aws dynamodb describe-table --table-name bucketchatwootlock \
--query "Table.TableStatus"
```

![image.png](imagens/image%204.png)

Verificando Versionamento do Bucket

```jsx
aws s3api get-bucket-versioning --bucket bucketchatwootprojetoaws
```

![image.png](imagens/image%205.png)

O S3 armazena o state de forma centralizada, permitindo que qualquer execução do Terraform utilize o mesmo estado.

**Lock do state com DynamoDB** é usado para evitar que 2 pipelines executem um **apply** ao mesmo tempo. Ao rodar a pipeline, o terraform cria um lock na tabela do DynamoDB, enquanto esse lock existir, ninguém conseguirá alterar o state do terraform.

---

# DEPLOY

 `chatwoot-dev/infra`:

```jsx
terraform init
terraform plan -out tfplan
terraform apply tfplan
```

![image.png](imagens/image%2016.png)

Essa pipeline irá criar os módulos:

- VPC
- Subnets
- Internet Gateway
- NAT Gateway
- Security Groups
- Cluster EKS
- Node Group
- RDS PostgreSQL
- Redis (ElastiCache)
- Bucket S3 para anexos
- Repositório ECR
- Secrets Manager (senha do banco)

![image.png](imagens/image%2017.png)

### CLUSTER ONLINE

![image.png](imagens/image%2018.png)

Com meu Cluster chatwoot-dev criado, posso me conectar ao kubeconfig

```jsx
aws eks update-kubeconfig --region us-east-1 --name chatwoot-dev
```

![image.png](imagens/image%2019.png)

### Verificando a infraestrutura

Instâncias EC2

```jsx
aws ec2 describe-instances \
  --query "Reservations[].Instances[].{ID:InstanceId,State:State.Name,Type:InstanceType,AZ:Placement.AvailabilityZone}" \
  --output table
```

![image.png](imagens/image%2020.png)

Elastic IPs

```jsx
for r in $(aws ec2 describe-regions --query "Regions[].RegionName" --output text); do
  echo "=== EIP em $r ==="
  aws ec2 describe-addresses --region $r --output table
done
```

![image.png](imagens/image%2021.png)

NAT Gateways

```jsx
for r in $(aws ec2 describe-regions --query "Regions[].RegionName" --output text); do
  echo "=== NAT em $r ==="
  aws ec2 describe-nat-gateways --region $r \
    --query "NatGateways[].{ID:NatGatewayId,State:State}" \
    --output table
done
```

![image.png](imagens/image%2022.png)

Load Balancers

```jsx
for r in $(aws ec2 describe-regions --query "Regions[].RegionName" --output text); do
  echo "=== LB em $r ==="
  aws elbv2 describe-load-balancers --region $r \
    --query "LoadBalancers[].{Name:LoadBalancerName,Type:Type}" \
    --output table
done
```

EKS

```jsx
for r in $(aws ec2 describe-regions --query "Regions[].RegionName" --output text); do
  echo "=== EKS em $r ==="
  aws eks list-clusters --region $r --output table
done
```

![image.png](imagens/image%2023.png)

VPCs

```jsx
aws ec2 describe-vpcs \
  --query "Vpcs[].{VPC:VpcId,CIDR:CidrBlock}" \
  --output table
```

![image.png](imagens/image%2024.png)

Subnets

```jsx
aws ec2 describe-subnets \
  --query "Subnets[].{Subnet:SubnetId,AZ:AvailabilityZone,CIDR:CidrBlock}" \
  --output table
```

![image.png](imagens/image%2025.png)

Verificando os nodes

```jsx
kubectl get nodes
```

![image.png](imagens/image%2026.png)

Verificando Pods

```jsx
kubectl get pods -A
```

![image.png](imagens/image%2027.png)

# Addons do EKS

Diretório:

```
terraform/chatwoot-dev/addons/eks
```

Comando:

```
terraform init
terraform plan
terraform apply
```

## Será instalado:

Dentro do cluster Kubernetes:

- Metrics Server
- AWS Load Balancer Controller
- ExternalDNS
- ArgoCD
- IAM Roles (IRSA)
- Policies AWS

![image.png](imagens/image%2028.png)

Verificando ALB Controller

```jsx
kubectl get svc -n kube-system aws-load-balancer-webhook-service
kubectl get endpoints -n kube-system aws-load-balancer-webhook-service
```

![image.png](imagens/image%2029.png)

Namespace

```jsx
kubectl get ns
```

![image.png](imagens/image%2030.png)

Verificando a IAM Role do ALB

```jsx
aws iam get-role --role-name chatwoot-dev-lbc-irsa
```

![image.png](imagens/image%2031.png)

ExternalDNS

```jsx
aws iam get-role --role-name chatwoot-dev-externaldns-irsa
```

![image.png](imagens/image%2032.png)

Polices do EKS

```jsx
aws iam get-policy --policy-arn arn:aws:iam::762012032320:policy/chatwoot-dev-lbc-policy
aws iam get-policy --policy-arn arn:aws:iam::762012032320:policy/chatwoot-dev-externaldns-policy
```

![image.png](imagens/image%2033.png)

# Infraestrutura pronta!

Agora irei efetuar o deploy da aplicação seguindo os padrões GitOPS com ArgoCD.

### GitOPS - Deploy Chatwoot com ArgoCD

Primeiramente irei verificar o conteúdo da namespace do ArgoCD.

```jsx
kubectl get pods -n argocd
```

![image.png](imagens/image%2034.png)

```jsx
kubectl get service -n argocd
```

![image.png](imagens/image%2035.png)

Pods e Services rodando, irei criar um tunel diretamente da minha máquina com o Pod na AWS com o Port-Forward.

```jsx
kubectl port-forward svc/argocd-server -n argocd 8080:80
```

![image.png](imagens/image%2036.png)

Assim posso acessar o ArgoCD da minha máquina diretamente

```jsx
http://localhost:8080
```

![image.png](imagens/image%2037.png)

Por padrão, o usuário do ArgoCD é admin. A senha terei que descriptografar o secret no service argocd-initial-admin-secret no formato Base64.

```jsx
kubectl -n argocd get secret argocd-initial-admin-secret \
-o jsonpath="{.data.password}" | base64 --decode
```

![image.png](imagens/image%2038.png)

5H3gt0HpxnqU-e-3

ArgoCD acessado.

![image.png](imagens/image%2039.png)

Apps-for-Apps

/terraform/chatwoot-dev/app/chatwoot/bootstrap/application.yaml

```jsx
kubectl apply -f application.yaml
```

![image.png](imagens/image%2040.png)

Após sincronizar, o ArgoCD irá efetuar o deploy dos manifests apontados no application.yaml

![image.png](imagens/image%2041.png)

Verificando as Namespaces

```jsx
kubectl get ns
```

![image.png](imagens/image%2042.png)

Verificando o SecretStore na namespace chatwoot

```jsx
kubectl get secretstore -n chatwoot
```

![image.png](imagens/image%2043.png)

Detalhando o secret

```jsx
kubectl describe secretstore aws-secretsmanager -n chatwoot
```

![image.png](imagens/image%2044.png)

Verificando o External Secret

```jsx
kubectl get externalsecret -n chatwoot
```

![image.png](imagens/image%2045.png)

```jsx
kubectl describe externalsecret chatwoot-secrets -n chatwoot
```

![image.png](imagens/image%2046.png)

Secret Kubernetes

```jsx
kubectl get secret -n chatwoot
```

![image.png](imagens/image%2047.png)

Detalhando:

```jsx
kubectl describe secret chatwoot-secrets -n chatwoot
```

![image.png](imagens/image%2048.png)

Eu consigo ver a chave gerada do Secret:

```jsx
kubectl get secret chatwoot-secrets -n chatwoot -o yaml
```

![image.png](imagens/image%2049.png)

Secret que o Chatwoot irá usar:

```jsx
kubectl get secret chatwoot-secrets -n chatwoot
```

![image.png](imagens/image%2050.png)

E por fim eu posso verificar se a chave gerada no K8S bate com o IRSA

```jsx
aws secretsmanager list-secrets | grep chatwoot
```

![image.png](imagens/image%2051.png)

---

---

---

---

---

/aplicação/chatwoot/application.yaml

O meu manifest application.yaml é do tipo Application, após realizar o apply, ele irá dizer para o ArgoCD  baixar o Chart do repo oficial que eu indiquei dentro do manifest e redenrizar todos os demais manifests dentro do namespace chatwoot.

# Analogia simples

- `argocd` = sala de controle
- `Application` = ordem de serviço
- `chatwoot` = local onde a obra será feita

Deploy do application

```jsx
kubectl apply -f application.yaml
```

![image.png](imagens/image%2052.png)

Após aplicar o application.yaml, o ArgoCD irá registrar e sincronizar todos os manifests no meu cluster.



---

## Banco de Dados do Chatwoot

Este projeto utiliza **Amazon RDS PostgreSQL** como banco de dados principal do Chatwoot.

O Chatwoot é uma aplicação baseada em Ruby on Rails e depende de um banco PostgreSQL para armazenar dados como usuários, contas, conversas, contatos, caixas de entrada, mensagens, configurações e demais informações da aplicação.

Embora o Helm Chart oficial do Chatwoot possa subir um PostgreSQL interno dentro do Kubernetes, foi adotado o uso de **RDS externo** para separar a camada de aplicação da camada de dados.

---


### Motivos para usar RDS

O uso do RDS traz alguns benefícios importantes:

- Banco de dados gerenciado pela AWS.
- Separação entre aplicação e dados.
- Menor risco de perda de dados em caso de problemas no cluster Kubernetes.
- Facilidade de backup e snapshots.
- Melhor aderência a uma arquitetura mais próxima de produção.
- Menor complexidade operacional dentro do Kubernetes.
- Possibilidade de atualizar/recriar o cluster EKS sem destruir o banco da aplicação.
- Melhor controle de rede por Security Groups.
- Melhor organização entre infraestrutura, aplicação e dados.

A arquitetura final segue esta ideia:

```text
Chatwoot Web/Worker no EKS
        ↓
Amazon RDS PostgreSQL




-Conectando ao RDS

```jsx
kubectl run psql-client \
  -n chatwoot \
  --rm -it \
  --image=postgres:16 \
  --env="PGPASSWORD=YtI0GwsLFtMhpnNbrKhyByCj" \
  -- psql \
  -h chatwoot-dev-postgres.car4ygsuqsqr.us-east-1.rds.amazonaws.com \
  -p 5432 \
  -U chatwoot \
  -d postgres \
  "sslmode=require"
```

![image.png](imagens/image%2053.png)

Ver senha Real do POSTGRES_PASSWORD

```jsx
kubectl get secret chatwoot-secrets -n chatwoot -o jsonpath="{.data.POSTGRES_PASSWORD}" | base64 -d
```

![image.png](imagens/image%2054.png)

Salvando a senha:

```jsx
DB_PASSWORD=$(kubectl get secret chatwoot-secrets -n chatwoot -o jsonpath='{.data.POSTGRES_PASSWORD}' | base64 -d)
```

Entrando:

```jsx
kubectl run psql-client \
  -n chatwoot \
  --rm -i \
  --restart=Never \
  --image=postgres:16 \
  --env="PGPASSWORD=$DB_PASSWORD" \
  --env="PGSSLMODE=require" \
  --command -- psql \
  -h chatwoot-dev-postgres.car4ygsuqsqr.us-east-1.rds.amazonaws.com \
  -p 5432 \
  -U chatwoot \
  -d postgres \
  -c "\conninfo"
```

Criando schema do banco

```jsx
kubectl run chatwoot-db-prepare \
  -n chatwoot \
  --rm -it \
  --restart=Never \
  --image=chatwoot/chatwoot:v4.11.1 \
  --env-from=secretRef:chatwoot-env \
  --env-from=secretRef:chatwoot-secrets \
  --command -- bundle exec rails db:prepare
```

![image.png](imagens/image%2055.png)

![image.png](imagens/imagens/image%2056.png)

### Bootstrap

![image.png](imagens/image%2057.png)

```jsx
kubectl apply -f application.yaml
```

```jsx
kubectl get ns chatwoot
kubectl get secretstore -n chatwoot
kubectl get externalsecret -n chatwoot
kubectl get secret -n chatwoot
```

Aplicando DB

```jsx
kubectl apply -f chatwoot-db-prepare.yaml
```

![image.png](imagens/image%2058.png)

Validando

```jsx
kubectl get jobs -n chatwoot
kubectl get pods -n chatwoot
kubectl logs -n chatwoot -f job/chatwoot-db-prepare
```

```jsx
1. Criar certificado ACM e validar DNS na Hostinger
2. Subir infra AWS com Terraform
   - VPC
   - EKS
   - RDS
   - Redis/S3/Secrets
3. Conectar kubectl no EKS
4. Subir addons com Terraform
   - ArgoCD
   - External Secrets
   - AWS Load Balancer Controller
   - IRSA
5. Aplicar bootstrap da aplicação
   - namespace
   - SecretStore
   - ExternalSecret
   - secrets finais
6. Validar conexão EKS → RDS
7. Criar banco chatwoot, se necessário
8. Rodar db:prepare/db:migrate
9. Sincronizar aplicação no ArgoCD
10. Validar pods, service e ingress
11. Apontar CNAME chatwoot na Hostinger para o ALB
12. Testar https://chatwoot.ronney.tech
```