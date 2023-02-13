terraform {
  required_version = ">= 0.13"
  required_providers {
    kubectl = {
      source  = "gavinbunney/kubectl"
    }
  }
}

provider "kubectl" {
  version = ">= 1.14.0"
  host                   = local.api_server
  client_certificate     = local.client_certificate
  client_key             = local.client_key
  cluster_ca_certificate = local.cluster_ca_certificate
}



provider "azurerm" {
  version = "2.44.0"
  subscription_id = var.subscription_id
  client_id       = var.client_id
  client_secret   = var.client_secret
  tenant_id       = var.tenant_id
features {}
}


provider "helm" {
  kubernetes {
    host                   = "${azurerm_kubernetes_cluster.example.kube_config.0.host}"
    username               = "${azurerm_kubernetes_cluster.example.kube_config.0.username}"
    password               = "${azurerm_kubernetes_cluster.example.kube_config.0.password}"
    client_certificate     = "${base64decode(azurerm_kubernetes_cluster.example.kube_config.0.client_certificate)}"
    client_key             = "${base64decode(azurerm_kubernetes_cluster.example.kube_config.0.client_key)}"
    cluster_ca_certificate = "${base64decode(azurerm_kubernetes_cluster.example.kube_config.0.cluster_ca_certificate)}"
  }
}


data "azurerm_resource_group" "example" {
  depends_on =[azurerm_resource_group.example]
  name = var.rg-name
}

output "id" {
  value = data.azurerm_resource_group.example.id
}

resource "azurerm_resource_group" "example" {
  name     = var.rg-name
  location = var.location
}


resource "azurerm_kubernetes_cluster" "example" {
  name                = var.aks-name
  location            = data.azurerm_resource_group.example.location
  resource_group_name = data.azurerm_resource_group.example.name
  dns_prefix          = "exampleakscluster"

  default_node_pool {
    name       = "default"
    node_count = 1
    vm_size    = "Standard_D2_v2"
  }

  service_principal {
    client_id     = var.client_id
    client_secret = var.client_secret
  }

  role_based_access_control {
    enabled = true
  }
}

output "client_certificate" {
  value     = azurerm_kubernetes_cluster.example.kube_config.0.client_certificate
  sensitive = true
}
output "kube_config" {
  value = azurerm_kubernetes_cluster.example.kube_config_raw

  sensitive = true
}

output "publicip" {
  value     = azurerm_kubernetes_cluster.example.kube_config.0.host
}



resource "null_resource" "authenticate_kubectl" {
  provisioner "local-exec" {
    command = <<EOF
      echo "${azurerm_kubernetes_cluster.example.kube_config_raw}" > kubeconfig.yaml
      export KUBECONFIG=kubeconfig.yaml
      kubectl config use-context "$(kubectl config current-context)"
    EOF
  }
}



data "azurerm_kubernetes_cluster" "example" {
  depends_on =[azurerm_kubernetes_cluster.example]
  name                = var.aks-name
  resource_group_name = data.azurerm_resource_group.example.name
}

resource "azurerm_container_registry" "registry" {
  name                  = "registrywwww"
  resource_group_name   = var.rg-name
  location              = var.location
  sku                   = "Standard"
  admin_enabled         = false
}


locals {
  client_certificate     = base64decode(data.azurerm_kubernetes_cluster.example.kube_config.0.client_certificate)
  client_key             = base64decode(data.azurerm_kubernetes_cluster.example.kube_config.0.client_key)
  cluster_ca_certificate = base64decode(data.azurerm_kubernetes_cluster.example.kube_config.0.cluster_ca_certificate)
  api_server             = data.azurerm_kubernetes_cluster.example.kube_config.0.host
}

provider "kubernetes" {
  version = ">= 1.14.0"
  host                   = local.api_server
  client_certificate     = local.client_certificate
  client_key             = local.client_key
  cluster_ca_certificate = local.cluster_ca_certificate
}


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


data "template_file" "ingress" {
  template = file("./modules/ingress/ingress.yaml")

  vars = {
    public_ip = "${azurerm_kubernetes_cluster.example.kube_config.0.host}"
  }
}

resource "kubectl_manifest" "apply" {
  depends_on = [ data.template_file.ingress]
  yaml_body = data.template_file.ingress.rendered
}

data "kubectl_file_documents" "aescrds" {
    content = file("./modules/ambassador/aes-crds.yaml")
}

resource "kubectl_manifest" "apply1" {
    count     = length(data.kubectl_file_documents.aescrds.documents)
    yaml_body = element(data.kubectl_file_documents.aescrds.documents, count.index)
}

data "kubectl_file_documents" "aes" {
    content = file("./modules/ambassador/aes.yaml")
}

resource "kubectl_manifest" "apply2" {
    count     = length(data.kubectl_file_documents.aes.documents)
    yaml_body = element(data.kubectl_file_documents.aes.documents, count.index)
}

data "kubectl_file_documents" "listener" {
    content = file("./modules/ambassador/listener.yaml")
}

resource "kubectl_manifest" "apply3" {
    count     = length(data.kubectl_file_documents.listener.documents)
    yaml_body = element(data.kubectl_file_documents.listener.documents, count.index)
}

data "template_file" "api" {
  template = file("./modules/ambassador/api-ingress.yaml")

  vars = {
    public_ip = "${azurerm_kubernetes_cluster.example.kube_config.0.host}"
  }
}

resource "kubectl_manifest" "apply4" {
  depends_on = [ data.template_file.api]
  yaml_body = data.template_file.api.rendered
}
