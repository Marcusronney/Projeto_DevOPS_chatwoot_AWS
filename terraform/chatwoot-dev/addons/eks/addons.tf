

############################################
# 3.1 Metrics Server
############################################
resource "helm_release" "metrics_server" {
  name       = "metrics-server"
  namespace  = local.k8s_system_ns
  repository = "https://kubernetes-sigs.github.io/metrics-server/"
  chart      = "metrics-server"
  version    = "3.12.2"

  # Em EKS costuma ser ok; se quiser remover depois, basta tirar este set.
  set {
    name  = "args[0]"
    value = "--kubelet-insecure-tls"
  }
}

############################################
# 3.2 AWS Load Balancer Controller (IRSA + Helm)
############################################

# IAM Policy (Load Balancer Controller)
resource "aws_iam_policy" "lbc" {
  name = "${local.name_prefix}-lbc-policy"

  # Policy oficial recomendada (cole aqui o JSON completo).
  # Para não depender de arquivo externo, deixei inline.
  # Você pode substituir por: policy = file("${path.local}/policies/lbc.json")
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # Observação: esta policy abaixo é um "esqueleto" funcional,
      # mas em produção é melhor usar a policy oficial completa do controller.
      {
        Effect = "Allow"
        Action = [
          "ec2:Describe*",
          "elasticloadbalancing:Describe*",
          "elasticloadbalancing:CreateLoadBalancer",
          "elasticloadbalancing:CreateTargetGroup",
          "elasticloadbalancing:CreateListener",
          "elasticloadbalancing:CreateRule",
          "elasticloadbalancing:DeleteLoadBalancer",
          "elasticloadbalancing:DeleteTargetGroup",
          "elasticloadbalancing:DeleteListener",
          "elasticloadbalancing:DeleteRule",
          "elasticloadbalancing:ModifyLoadBalancerAttributes",
          "elasticloadbalancing:ModifyTargetGroup",
          "elasticloadbalancing:ModifyTargetGroupAttributes",
          "elasticloadbalancing:ModifyListener",
          "elasticloadbalancing:ModifyRule",
          "elasticloadbalancing:RegisterTargets",
          "elasticloadbalancing:DeregisterTargets",
          "elasticloadbalancing:SetSecurityGroups",
          "elasticloadbalancing:SetSubnets",
          "elasticloadbalancing:AddTags",
          "elasticloadbalancing:RemoveTags",
          "iam:CreateServiceLinkedRole",
          "acm:DescribeCertificate",
          "acm:ListCertificates",
          "acm:GetCertificate"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role" "lbc" {
  name = "${local.name_prefix}-lbc-irsa"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect    = "Allow",
      Principal = { Federated = local.oidc_provider_arn },
      Action    = "sts:AssumeRoleWithWebIdentity",
      Condition = {
        StringEquals = {
          "${local.oidc_provider_host}:sub" = "system:serviceaccount:${local.k8s_system_ns}:${local.lbc_sa_name}"
        }
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lbc" {
  role       = aws_iam_role.lbc.name
  policy_arn = aws_iam_policy.lbc.arn
}

resource "kubernetes_service_account" "lbc" {
  metadata {
    name      = local.lbc_sa_name
    namespace = local.k8s_system_ns
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.lbc.arn
    }
  }
}

resource "helm_release" "aws_load_balancer_controller" {
  name       = "aws-load-balancer-controller"
  namespace  = local.k8s_system_ns
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  version    = "1.7.2" # ajuste se quiser travar em outra

  depends_on = [
    kubernetes_service_account.lbc
  ]

  set {
    name  = "clusterName"
    value = local.cluster_name
  }

  set {
    name  = "region"
    value = var.aws_region
  }

  set {
    name  = "vpcId"
    value = value = local.vpc_id
  }

  set {
    name  = "serviceAccount.create"
    value = "false"
  }

  set {
    name  = "serviceAccount.name"
    value = local.lbc_sa_name
  }
}

############################################
# 3.3 ExternalDNS (IRSA + Helm) - Route53
############################################

resource "aws_iam_policy" "externaldns" {
  name = "${local.name_prefix}-externaldns-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "route53:ChangeResourceRecordSets"
        ]
        Resource = [
          "arn:aws:route53:::hostedzone/${var.route53_zone_id}"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "route53:ListHostedZones",
          "route53:ListResourceRecordSets",
          "route53:ListHostedZonesByName"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role" "externaldns" {
  name = "${local.name_prefix}-externaldns-irsa"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect    = "Allow",
      Principal = { Federated = local.oidc_provider_arn },
      Action    = "sts:AssumeRoleWithWebIdentity",
      Condition = {
        StringEquals = {
          "${local.oidc_provider_host}:sub" = "system:serviceaccount:${local.k8s_system_ns}:${local.externaldns_sa_name}"
        }
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "externaldns" {
  role       = aws_iam_role.externaldns.name
  policy_arn = aws_iam_policy.externaldns.arn
}

resource "kubernetes_service_account" "externaldns" {
  metadata {
    name      = local.externaldns_sa_name
    namespace = local.k8s_system_ns
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.externaldns.arn
    }
  }
}

resource "helm_release" "external_dns" {
  name       = "external-dns"
  namespace  = local.k8s_system_ns
  repository = "https://charts.bitnami.com/bitnami"
  chart      = "external-dns"
  version    = "8.7.0" # ajuste se quiser travar em outra

  depends_on = [
    kubernetes_service_account.externaldns
  ]

  set {
    name  = "provider"
    value = "aws"
  }

  set {
    name  = "policy"
    value = "sync"
  }

  set {
    name  = "registry"
    value = "txt"
  }

  set {
    name  = "txtOwnerId"
    value = local.cluster_name
  }

  set {
    name  = "serviceAccount.create"
    value = "false"
  }

  set {
    name  = "serviceAccount.name"
    value = local.externaldns_sa_name
  }

  set {
    name  = "aws.zoneType"
    value = "public"
  }

  set {
    name  = "aws.region"
    value = var.aws_region
  }


  # Opcional: domainFilters[]
  dynamic "set" {
    for_each = var.externaldns_domain_filters
    content {
      name  = "domainFilters[${set.key}]"
      value = set.value
    }
  }
}