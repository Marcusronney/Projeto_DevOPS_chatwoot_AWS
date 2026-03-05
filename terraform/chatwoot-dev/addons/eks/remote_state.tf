data "terraform_remote_state" "infra" {
  backend = "s3"
  config = {
    bucket         = "bucketchatwootprojetoaws"
    key            = "chatwoot/dev/infra.tfstate"   # ajuste para a key real do infra
    region         = "us-east-1"
    dynamodb_table = "bucketchatwootlock"
    encrypt        = true
  }
}

locals {
  name_prefix        = "chatwoot-dev" # ou derive de vars
  cluster_name       = data.terraform_remote_state.infra.outputs.eks_cluster_name
  vpc_id             = data.terraform_remote_state.infra.outputs.vpc_id
  oidc_provider      = data.terraform_remote_state.infra.outputs.oidc_provider
  oidc_provider_arn  = data.terraform_remote_state.infra.outputs.oidc_provider_arn

  oidc_provider_host = replace(local.oidc_provider, "https://", "")
}