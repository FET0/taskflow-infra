CLUSTER_NAME := taskflow
K8S_VERSION  := 1.28.14

.PHONY: cluster-up
cluster-up:
	k3d cluster create $(CLUSTER_NAME) \
		--image rancher/k3s:v$(K8S_VERSION)-k3s1 \
		--servers 1 \
		--agents 2 \
		--port 80:80@loadbalancer \
		--port 443:443@loadbalancer \
		--k3s-arg "--disable=traefik@server:0"   # we'll install our own ingress later if needed

.PHONY: cluster-down
cluster-down:
	k3d cluster delete $(CLUSTER_NAME)

.PHONY: infra-init
infra-init:
	terraform init

.PHONY: infra-plan
infra-plan:
	terraform plan

.PHONY: infra-apply
infra-apply:
	terraform apply -auto-approve

.PHONY: bootstrap
bootstrap: cluster-up infra-init infra-apply
	@echo "Waiting for ArgoCD and Sealed Secrets..."
	kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd
	kubectl wait --for=condition=ready --timeout=120s pod -l app.kubernetes.io/name=sealed-secrets -n kube-system
	@echo "Bootstrap complete."
	@echo "Access ArgoCD: https://localhost:443 (accept self-signed cert)"
	@echo "Login: admin / $(shell kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d)"

.PHONY: destroy
destroy: cluster-down
	terraform destroy -auto-approve
