# 📋 Análise Detalhada: Terraform Chatwoot + EKS AWS

**Data da Análise:** 04/03/2026  
**Estado:** Infraestrutura Parcial (50%-60% Completa)

---

## ✅ O QUE FOI CONSTRUÍDO

### 1. **INFRAESTRUTURA DE REDE**
- ✅ **VPC com 10.0.0.0/16**
  - Subnets públicas e privadas em múltiplas AZs (padrão 2 AZs)
  - Tags Kubernetes para ALB e EKS
  - NAT Gateway por AZ (resiliente)
  - DNS habilitado

### 2. **CLUSTER EKS**
- ✅ **Kubernetes 1.29**
  - VPC integrada
  - Node Group gerenciado (t3.medium) com 2 nós (min: 1, max: 3)
  - Endpoint público (facilita acesso durante desenvolvimento)
  - OIDC Provider configurado para IRSA

### 3. **CONTAINER REGISTRY**
- ✅ **ECR Repository**
  - Repositório para imagens Chatwoot
  - Lifecycle policy (mantém últimas 30 imagens)
  - Mutável

### 4. **BANCO DE DADOS**
- ✅ **RDS PostgreSQL 16**
  - DB name: `chatwoot`
  - Armazenado em subnets privadas
  - Criptografia habilitada
  - Backup automático (7 dias)
  - Senha gerada automaticamente via Secrets Manager
  - Security Group restrito apenas ao EKS

### 5. **CACHE**
- ✅ **ElastiCache Redis 7**
  - Single node (t4g.micro)
  - Subnets privadas
  - Security Group restrito apenas ao EKS
  - Port 6379

### 6. **STORAGE**
- ✅ **S3 Bucket**
  - Para anexos do Chatwoot
  - Versionamento habilitado
  - Público access bloqueado
  - Criptografia SSE

### 7. **ADDONS KUBERNETES**
- ✅ **Metrics Server** (v3.12.2)
  - Para HPA (horizontal pod autoscaling)

- ✅ **AWS Load Balancer Controller** (v1.7.2)
  - IRSA configurado
  - Cria ALBs automaticamente via Ingress

- ✅ **ExternalDNS** (v8.7.0)
  - Integração com Route53
  - Sincroniza Ingress/Services com DNS
  - IRSA para acesso ao Route53

### 8. **PROVIDERS KUBERNETES**
- ✅ Kubernetes provider
- ✅ Helm provider
- Ambos com autenticação automática via EKS

---

## ❌ O QUE FALTA

### 🔴 **CRÍTICO** (Impede Deploy)

#### 1. **Helm Chart / Deployment do Chatwoot**
```
FALTA: Nenhum Chart Helm ou Deployment K8s para a aplicação Chatwoot
NECESSÁRIO:
  - Helm Chart do Chatwoot (buscar em helm.chatwoot.com ou criar custom)
  - OU Kubernetes Manifests (Deployment, Service, ConfigMap, Secret)
  - Specifications:
    - Pods da aplicação (Web, Workers, Sidekiq)
    - Image do Chatwoot no ECR
    - Resource requests/limits
    - Liveness/Readiness probes
```

#### 2. **Variáveis de Ambiente da Aplicação**
```
FALTA: ConfigMaps e Secrets com env vars do Chatwoot
NECESSÁRIO:
  - RAILS_ENV=production
  - SECRET_KEY_BASE
  - DATABASE_URL (de RDS)
  - REDIS_URL (de ElastiCache)
  - AWS_REGION, AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY (para S3)
  - SMTP_* (email settings)
  - FRONTEND_URL
  - RAILS_LOG_TO_STDOUT
  - activeStorage.store = :amazon (config para usar S3)
```

#### 3. **IAM Role para Pods Acessarem AWS (IRSA)**
```
FALTA: Service Account + IAM Role para a aplicação Chatwoot
NECESSÁRIO:
  - S3 access (read/write attachments)
  - Secrets Manager access (ler DB password)
  - CloudWatch Logs (logging)
  
Exemplo:
  - IAM Policy with S3, Secrets Manager actions
  - Trust policy para OIDC + ServiceAccount
  - Kubernetes ServiceAccount anotado
```

#### 4. **Namespace Kubernetes**
```
FALTA: ns=chatwoot ou similar
```

#### 5. **Services Kubernetes**
```
FALTA: ClusterIP ou LoadBalancer para Chatwoot (porta 3000)
```

#### 6. **Ingress**
```
FALTA: Ingress para expor Chatwoot via ALB
NECESSÁRIO:
  - Host: chatwoot.seudominio.com
  - SSL/TLS via AWS Certificate Manager
  - Path-based routing se houver múltiplos serviços
  - ExternalDNS vai criar o Route53 record automaticamente
```

### 🟡 **IMPORTANTE** (Funciona, mas incompleto)

#### 7. **SSL/TLS & HTTPS**
```
ATUAL: ExternalDNS referenciado, mas Route53 zone não está no terraform.tfvars
NECESSÁRIO:
  - Descomentar route53_zone_id e domain_name em terraform.tfvars
  - ACM Certificate para HTTPS (wildcard ou específico)
  - ALB Listener com redirecionamento HTTP → HTTPS
```

#### 8. **Health Checks & Autoscaling**
```
FALTA:
  - Liveness/Readiness Probes no Deployment
  - HorizontalPodAutoscaler (HPA) - Metrics Server existe, mas HPA não
  - Recomendação: baseado em CPU/Memory (80% threshold)
```

#### 9. **Logging & Monitoring**
```
FALTA:
  - CloudWatch Log Group para Chatwoot
  - Fluentd/Fluent-Bit para coletar logs dos pods
  - CloudWatch Container Insights (opcional, mas recomendado)
  - Prometheus/Grafana (opcional)
  
ATUALMENTE: Metrics Server instalado, mas não há scraping de métricas
```

#### 10. **Backup Strategy**
```
CONFIGURADO:
  - RDS backup 7 dias ✅
  
FALTA:
  - S3 cross-region replication
  - Backup automático de dados críticos
  - Disaster recovery plan
```

#### 11. **Resource Quotas & Limits**
```
FALTA: Network Policies, Pod Security Policies, Resource Quotas por namespace
```

### 🟢 **OPCIONAL** (Melhorias Futuras)

#### 12. **Segurança Avançada**
- VPN/Tunnel para acesso ao EKS (atualmente endpoint público)
- WAF na ALB
- Security Group mais restritivo
- Criptografia entre pods (mTLS via Istio/Linkerd)

#### 13. **CI/CD Integration**
- GitHub Actions / GitLab CI para build e push no ECR
- ArgoCD ou Flux para GitOps
- Helm values diferenciadas por ambiente (dev/staging/prod)

#### 14. **Dev Experience**
- Auto-pilot IAM policies via External Secrets Operator
- Service Mesh (Istio)
- Kyverno para policy enforcement

#### 15. **Cost Optimization**
- ElastiCache atualmente é single t4g.micro (considerar multi-az)
- RDS também single availability zone (considerar multi-az)
- Spot Instances para node group (economia 70%)

---

## 📊 CHECKLIST DE PRÓXIMOS PASSOS

### Fase 1: Essencial (Deploy Funcional)
- [ ] 1. Adicionar Helm Chart/Deployment do Chatwoot
- [ ] 2. Criar ConfigMap com env vars da aplicação
- [ ] 3. Criar IAM Role + ServiceAccount para Chatwoot (IRSA)
- [ ] 4. Criar Service (ClusterIP)
- [ ] 5. Criar Ingress com ALB
- [ ] 6. Descomentar Route53 zone_id e criar ACM cert
- [ ] 7. Testar deploy: `terraform apply` → chatwoot acessível via URL

### Fase 2: Confiabilidade (Produção)
- [ ] 8. Adicionar Liveness/Readiness Probes
- [ ] 9. Configurar HPA (CPU 80%)
- [ ] 10. Implementar CloudWatch Logs
- [ ] 11. Upgrade RDS/Redis para Multi-AZ (alta disponibilidade)
- [ ] 12. Network Policies (pod-to-pod communication)

### Fase 3: Otimização (Maturidade)
- [ ] 13. GitOps (ArgoCD)
- [ ] 14. Monitoring (Prometheus + Grafana)
- [ ] 15. Backup/Disaster Recovery
- [ ] 16. Cost Analysis

---

## 🔧 EXEMPLO: ESTRUTURA FALTANTE

```hcl
# Estrutura que falta adicionar em terraform/chatwoot/dev/:

chatwoot/
├── chatwoot-namespace.tf       ← novo
├── chatwoot-serviceaccount.tf  ← novo (com IRSA)
├── chatwoot-configmap.tf       ← novo
├── chatwoot-secret.tf          ← novo
├── chatwoot-service.tf         ← novo
├── chatwoot-ingress.tf         ← novo
├── chatwoot-deployment.tf      ← novo (or use Helm)
├── chatwoot-hpa.tf             ← novo
└── eks/
    └── cloudwatch-logging.tf   ← novo
```

---

## 📈 TIMELINE ESTIMADA

| Fase | Tarefas | Tempo | Prioridade |
|------|---------|-------|-----------|
| **Fase 1** | 1-7 (Essencial) | 2-3 dias | 🔴 Crítica |
| **Fase 2** | 8-12 (Confiabilidade) | 1-2 semanas | 🟡 Alta |
| **Fase 3** | 13-16 (Otimização) | 2-4 semanas | 🟢 Média |

---

## 🎯 RECOMENDAÇÕES IMEDIATAS

1. **Use Helm Chart oficial** (se disponível) em vez de Kubernetes manifests puros
2. **Descomentar Route53** - necessário para DNS/HTTPS
3. **Implementar ServiceAccount com IRSA** - segurança: sem credenciais hardcoded
4. **Adicionar Security Group Rule para RDS/Redis** - já está 80% pronto
5. **Upgrade EKS endpoint** - considerar privado + bastion após deploy inicial

---

## 📝 CONCLUSÃO

✅ **Infraestrutura AWS está ~60% pronta:**
- Networking: ✅ Completa
- EKS: ✅ Funcional
- Banco de Dados: ✅ Pronto
- Cache: ✅ Pronto
- Addons Kubernetes: ✅ Instalados

❌ **Faltam aplicação e configurações Kubernetes:**
- Deployment/Helm Chart do Chatwoot
- Configurações de ambiente
- Exposição da aplicação (Ingress + ALB)
- Autoscaling e monitoring

**Próximo passo:** Implementar manifests Kubernetes para deploy do Chatwoot (2-3 dias de trabalho)
