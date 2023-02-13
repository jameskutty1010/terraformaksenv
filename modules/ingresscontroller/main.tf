resource "helm_release" "nginx_ingress" {
  depends_on = [ azurerm_kubernetes_cluster.example ]
  name = "nginx-ingress-controller"
  namespace = "default"
  repository = "https://charts.bitnami.com/bitnami"
  chart      = "nginx-ingress-controller"
  set {
    name  = "service.type"
    value = "LoadBalancer"
  }
}
