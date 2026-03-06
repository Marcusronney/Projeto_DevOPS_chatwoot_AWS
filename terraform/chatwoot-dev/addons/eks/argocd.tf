resource "kubernetes_namespace_v1" "argocd" {
  metadata {
    name = "argocd"
  }
}

resource "helm_release" "argocd" {
  name       = "argocd"
  namespace  = kubernetes_namespace_v1.argocd.metadata[0].name
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = "7.7.16"

  timeout          = 900
  wait             = true
  atomic           = true
  create_namespace = false

  depends_on = [kubernetes_namespace_v1.argocd]

  set {
    name  = "global.domain"
    value = "argocd.ronney.tech"
  }

  set {
    name  = "configs.params.server\\.insecure"
    value = "true"
  }

  set {
    name  = "server.service.type"
    value = "ClusterIP"
  }

  set {
    name  = "server.ingress.enabled"
    value = "true"
  }

  set {
    name  = "server.ingress.ingressClassName"
    value = "alb"
  }

  set {
    name  = "server.ingress.hostname"
    value = "argocd.ronney.tech"
  }

  set {
    name  = "server.ingress.path"
    value = "/"
  }

  set {
    name  = "server.ingress.pathType"
    value = "Prefix"
  }

  set {
    name  = "server.ingress.annotations.alb\\.ingress\\.kubernetes\\.io/scheme"
    value = "internet-facing"
  }

  set {
    name  = "server.ingress.annotations.alb\\.ingress\\.kubernetes\\.io/target-type"
    value = "ip"
  }

  set {
    name  = "server.ingress.annotations.alb\\.ingress\\.kubernetes\\.io/listen-ports"
    value = "[{\"HTTP\":80}]"
  }

  set {
    name  = "server.ingress.annotations.external-dns\\.alpha\\.kubernetes\\.io/hostname"
    value = "argocd.ronney.tech"
  }
}