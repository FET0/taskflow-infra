# taskflow-infra/main.tf

terraform {
  required_version = ">= 1.3"
  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.12"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
  }
  # If you want remote state (strongly recommended for cloud), uncomment:
  # backend "s3" { ... }
}

provider "helm" {
  kubernetes {
    config_path = "~/.kube/config"   # k3d writes here
  }
}

provider "kubernetes" {
  config_path = "~/.kube/config"
}

# ---------- ArgoCD ----------
resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  namespace        = "argocd"
  create_namespace = true
  version          = "5.46.0"  # pin a version for reproducibility

  values = [
    <<-YAML
    server:
      service:
        type: LoadBalancer
    YAML
  ]
}

# ---------- Sealed Secrets ----------
resource "helm_release" "sealed_secrets" {
  name             = "sealed-secrets"
  repository       = "https://bitnami-labs.github.io/sealed-secrets"
  chart            = "sealed-secrets"
  namespace        = "kube-system"
  create_namespace = false   # kube-system already exists
  version          = "2.13.3"
}

# After the controller is installed, we fetch its public certificate
# so developers can encrypt secrets offline (optional but professional).
resource "local_file" "sealed_secrets_cert" {
  depends_on = [helm_release.sealed_secrets]
  content    = data.kubernetes_secret.sealed_secrets_cert.data["tls.crt"]
  filename   = "${path.module}/sealed-secrets-cert.pem"
}

data "kubernetes_secret" "sealed_secrets_cert" {
  metadata {
    name      = "sealed-secrets-key"
    namespace = "kube-system"
  }
}
