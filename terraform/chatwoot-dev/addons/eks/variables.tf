variable "aws_region" {
  type    = string
  default = "us-east-1"
}

# Hosted Zone do Route53 onde o ExternalDNS vai criar os records
variable "route53_zone_id" {
  type = string
}

# Opcional: restringe quais domínios o ExternalDNS pode gerenciar
variable "externaldns_domain_filters" {
  type    = list(string)
  default = []
}