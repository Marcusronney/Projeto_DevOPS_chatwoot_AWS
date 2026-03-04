############################################
# Argo CD (Helm)
############################################

# Namespace do ArgoCD
resource "kubernetes_namespace" "argocd" {
  metadata {
    name = "argocd"
  }
}

# Instala Argo CD via Helm
resource "helm_release" "argocd" {
  name       = "argocd"
  namespace  = kubernetes_namespace.argocd.metadata[0].name
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = "6.7.18" # você pode travar numa versão diferente

  # Garante que o namespace existe antes
  depends_on = [kubernetes_namespace.argocd]

  # Recomendo manter simples no começo: acesso via port-forward.
  # Depois você pode habilitar Ingress/ALB quando quiser.

  # Boas práticas mínimas
  set {
    name  = "configs.params.server\\.insecure"
    value = "true"
  }

  # Mantém o Service do server como ClusterIP (port-forward)
  set {
    name  = "server.service.type"
    value = "ClusterIP"
  }

  # (Opcional) Se você quer HA depois, habilite replicas e redis HA etc.
  # Por enquanto, dev/lab: default do chart.
}