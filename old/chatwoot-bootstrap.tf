resource "kubernetes_namespace_v1" "chatwoot" {
  metadata {
    name = "chatwoot"
  }
}

resource "kubernetes_secret_v1" "chatwoot_secrets" {
  metadata {
    name      = "chatwoot-secrets"
    namespace = kubernetes_namespace_v1.chatwoot.metadata[0].name
  }

  type = "Opaque"

  string_data = {
    SECRET_KEY_BASE  = var.chatwoot_secret_key_base
    POSTGRES_PASSWORD = var.chatwoot_postgres_password
    REDIS_PASSWORD    = var.chatwoot_redis_password
  }

  depends_on = [kubernetes_namespace_v1.chatwoot]
}