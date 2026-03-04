terraform {
  backend "s3" {
    bucket         = "bucketchatwootprojetoaws"
    key            = "chatwoot/dev/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "bucketchatwootlock"
    encrypt        = true
  }
}