variable "argocd_admin_password" {
  description = "Initial admin password for ArgoCD (bcrypt hash)"
  type        = string
  sensitive   = true
}
