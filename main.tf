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
    time = {
      source  = "hashicorp/time"
      version = "~> 0.9"
    }
    # ADDED: This provider safely bypasses pre-install validation
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "~> 1.14"
    }
  }
}

provider "helm" {
  kubernetes {
    config_path = "~/.kube/config"
  }
}

provider "kubernetes" {
  config_path = "~/.kube/config"
}

# ADDED: Configuration for the kubectl provider
provider "kubectl" {
  config_path = "~/.kube/config"
}

# ---------- ArgoCD ----------
resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://github.io"
  chart            = "argo-cd"
  namespace        = "argocd"
  create_namespace = true
  version          = "5.46.0"

  values = [
    <<-YAML
    server:
      service:
        type: LoadBalancer
    YAML
  ]
}

resource "time_sleep" "wait_for_argocd" {
  depends_on      = [helm_release.argocd]
  create_duration = "30s"
}

# MODIFIED: Swapped out kubernetes_manifest for kubectl_manifest
resource "kubectl_manifest" "argocd_root_app" {
  depends_on = [time_sleep.wait_for_argocd]
  
  # Uses raw yaml instead of HCL block layout
  yaml_body = <<-YAML
    apiVersion: argoproj.io/v1alpha1
    kind: Application
    metadata:
      name: root-app
      namespace: argocd
    spec:
      project: default
      source:
        repoURL: https://github.com
        targetRevision: main
        path: app-of-apps
      destination:
        server: https://default.svc
        namespace: argocd
      syncPolicy:
        automated:
          prune: true
          selfHeal: true
  YAML
}

# ---------- Sealed Secrets ----------
resource "helm_release" "sealed_secrets" {
  name             = "sealed-secrets"
  repository       = "https://github.io"
  chart            = "sealed-secrets"
  namespace        = "kube-system"
  create_namespace = false
  version          = "2.13.3"
}

resource "time_sleep" "wait_for_sealed_secrets" {
  depends_on      = [helm_release.sealed_secrets]
  create_duration = "20s"
}

data "kubernetes_secret" "sealed_secrets_cert" {
  depends_on = [time_sleep.wait_for_sealed_secrets]
  metadata {
    name      = "sealed-secrets-key"
    namespace = "kube-system"
  }
}

resource "local_file" "sealed_secrets_cert" {
  depends_on = [data.kubernetes_secret.sealed_secrets_cert]
  content    = try(data.kubernetes_secret.sealed_secrets_cert.data["tls.crt"], "Pending generation")
  filename   = "${path.module}/sealed-secrets-cert.pem"
}

