SHELL ?= /bin/bash

OS := $(shell uname -s | tr '[:upper:]' '[:lower:]')
ARCH := $(shell uname -m | sed 's/x86_64/amd64/')

LOCALBIN ?= ${PWD}/bin
export PATH := $(LOCALBIN):$(PATH)

bin:
	mkdir -p $(LOCALBIN)

plugin-bin:
	mkdir -p argocd-cmp-plugin/bin

##@ Install kind and argocd
KIND ?= $(LOCALBIN)/kind
KIND_VERSION ?= v0.16.0
K8S_VERSION ?= 1.23.12

.PHONY: kind
KIND = $(shell pwd)/bin/kind
kind: $(KIND) ## Download kind locally if necessary
$(KIND):
	test -s $(KIND) || GOBIN=$(LOCALBIN) go install sigs.k8s.io/kind@$(KIND_VERSION)

argocd-plugin-sockets:
	mkdir -p /tmp/argocd-plugin-sockets && chmod 777 /tmp/argocd-plugin-sockets

KIND_ADMIN_KUBECONFIG ?= $(PWD)/kubeconfig
start: kind cmp-plugin
	KUBECONFIG=$(KIND_ADMIN_KUBECONFIG) $(KIND) create cluster --wait 5m --config kind.yaml --image kindest/node:v${K8S_VERSION}
	@make -s argocd-setup

stop:
	kind delete cluster --name=kind || true

clean:
	rm -rf bin tmp kubeconfig argocd-cmp-plugin/bin

##@ Install argocd and configure the root:test workspace
ARGOCD ?= $(LOCALBIN)/argocd
ARGOCD_VERSION ?= v2.4.12
ARGOCD_DOWNLOAD_URL ?= https://github.com/argoproj/argo-cd/releases/download/v2.4.13/argocd-$(OS)-$(ARCH)
argocd: $(ARGOCD) ## Download argocd CLI locally if necessary
$(ARGOCD):
	curl -sL $(ARGOCD_DOWNLOAD_URL) -o $(ARGOCD)
	chmod +x $(ARGOCD)

ARGOCD_CMP_SERVER ?= $(LOCALBIN)/argocd-cmp-server
ARGOCD_CMP_SERVER_VERSION ?= v2.4.12
argocd-cmp-server: $(ARGOCD_CMP_SERVER)
$(ARGOCD_CMP_SERVER):
	git clone --branch $(ARGOCD_CMP_SERVER_VERSION) --depth=1 https://github.com/argoproj/argo-cd.git tmp/argo-cd || true
	cd tmp/argo-cd && make argocd-all BIN_NAME=argocd-cmp-server DIST_DIR=../../bin

CMP_PLUGIN ?= argocd-cmp-plugin/bin/argocd-glbc-plugin
cmp-plugin: $(CMP_PLUGIN)
$(CMP_PLUGIN): plugin.go
	mkdir -p argocd-cmp-plugin/bin
	GOOS=linux CGO_ENABLED=0 go build -o argocd-cmp-plugin/bin/argocd-glbc-plugin plugin.go
	chmod +x $(CMP_PLUGIN)

KUSTOMIZE ?= $(LOCALBIN)/kustomize
KUSTOMIZE_VERSION ?= v4.5.4
KUSTOMIZE_INSTALL_SCRIPT ?= "https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh"
.PHONY: kustomize
kustomize: $(KUSTOMIZE) ## Download kustomize locally if necessary.
$(KUSTOMIZE):
	curl -s $(KUSTOMIZE_INSTALL_SCRIPT) | bash -s -- $(subst v,,$(KUSTOMIZE_VERSION)) $(LOCALBIN)

YQ_VERSION ?= v4.28.1
YQ ?= $(LOCALBIN)/yq
YQ_DOWNLOAD_URL ?= https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/yq_$(OS)_$(ARCH)
yq: $(YQ) ## Download yq locally if necessary
$(YQ):
	curl -sL $(YQ_DOWNLOAD_URL) -o $(YQ)
	chmod +x $(YQ)

ARGOCD_PASSWD = $(shell kubectl --kubeconfig=$(KIND_ADMIN_KUBECONFIG) -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
argocd-password:
	@echo $(ARGOCD_PASSWD)

argocd-setup: export KUBECONFIG=$(KIND_ADMIN_KUBECONFIG)
argocd-setup: argocd kustomize
	$(KUSTOMIZE) build argocd/argocd-install | kubectl apply -f -
	kubectl -n argocd wait deployment argocd-server --for condition=Available=True --timeout=90s
	kubectl port-forward svc/argocd-server -n argocd 8080:80 > /dev/null  2>&1 &
	@echo -ne "\n\n\tConnect to ArgoCD UI in https://localhost:8080\n\n"
	@echo -ne "\t\tUser: admin\n"
	@echo -ne "\t\tPassword: "
	@make -s argocd-password
	@echo

argocd-port-forward-stop:
	pkill kubectl

argocd-example-glbc-application:
	kubectl -n argocd apply -f argocd/argocd-install/application-glbc-example.yaml

logs: export KUBECONFIG=$(KIND_ADMIN_KUBECONFIG)
logs:
	kubectl -n argocd logs -fl "app.kubernetes.io/name=argocd-repo-server" -c plugin
