# PoC for argocd CMP plugin dev environment

Start a kind cluster and install argocd in it. ArgoCD UI is accessible at https://localhost:8080

`make start`

Show the logs of the plugin

`make logs`

Try to create an ArgoCD Application pointing to this repo

`make argocd-example-glbc-application`

Tear down the environment with `make stop`
