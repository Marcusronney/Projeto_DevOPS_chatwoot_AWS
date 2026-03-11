data "aws_caller_identity" "current" {}

resource "aws_iam_policy" "external_secrets_sm" {
  name = "${local.name_prefix}-external-secrets-sm-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ReadChatwootSecrets"
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = [
          "arn:aws:secretsmanager:${var.aws_region}:${data.aws_caller_identity.current.account_id}:secret:chatwoot/dev/app*",
          "arn:aws:secretsmanager:${var.aws_region}:${data.aws_caller_identity.current.account_id}:secret:chatwoot-dev/rds/postgres*"
        ]
      }
    ]
  })
}
resource "aws_iam_role" "external_secrets_irsa" {
  name = "${local.name_prefix}-external-secrets-irsa"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = local.oidc_provider_arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${local.oidc_provider_host}:sub" = "system:serviceaccount:external-secrets:external-secrets"
        }
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "external_secrets_sm" {
  role       = aws_iam_role.external_secrets_irsa.name
  policy_arn = aws_iam_policy.external_secrets_sm.arn
}

resource "kubernetes_namespace_v1" "external_secrets" {
  metadata {
    name = "external-secrets"
  }
}

resource "kubernetes_service_account" "external_secrets" {
  metadata {
    name      = "external-secrets"
    namespace = kubernetes_namespace_v1.external_secrets.metadata[0].name

    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.external_secrets_irsa.arn
    }
  }
}

resource "helm_release" "external_secrets_operator" {
  name       = "external-secrets"
  namespace  = kubernetes_namespace_v1.external_secrets.metadata[0].name
  repository = "https://charts.external-secrets.io"
  chart      = "external-secrets"
  version    = "0.14.4"

  timeout = 900
  wait    = true
  atomic  = true

  depends_on = [
    kubernetes_service_account.external_secrets,
    aws_iam_role_policy_attachment.external_secrets_sm
  ]

  set {
    name  = "serviceAccount.create"
    value = "false"
  }

  set {
    name  = "serviceAccount.name"
    value = kubernetes_service_account.external_secrets.metadata[0].name
  }
}