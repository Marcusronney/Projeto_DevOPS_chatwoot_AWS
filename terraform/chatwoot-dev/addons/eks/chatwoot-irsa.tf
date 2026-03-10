resource "aws_iam_policy" "chatwoot_s3" {
  name = "${local.name_prefix}-chatwoot-s3-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::${local.attachments_bucket_name}"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ]
        Resource = [
          "arn:aws:s3:::${local.attachments_bucket_name}/*"
        ]
      }
    ]
  })
}

resource "aws_iam_role" "chatwoot_irsa" {
  name = "${local.name_prefix}-chatwoot-irsa"

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
          "${local.oidc_provider_host}:sub" = "system:serviceaccount:chatwoot:chatwoot"
        }
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "chatwoot_irsa_s3" {
  role       = aws_iam_role.chatwoot_irsa.name
  policy_arn = aws_iam_policy.chatwoot_s3.arn
}