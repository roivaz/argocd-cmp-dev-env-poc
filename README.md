# PoC for argocd CMP plugin dev environment

Start a kind cluster and install argocd in it. ArgoCD UI is accessible at https://localhost:8080

`make start`

Show the logs of the plugin

`make logs`

Try to create an ArgoCD Application pointing to this repo, to path `manifests/test-app`. This directory has a secret with the syntax that the avp plugin expects, so you should see calls in the logs of the argocd-cmp-server. The Application creation will fail because the avp plugin has no Vault configuration, but it's enough to see that the grpc communication through the shared unix socket is working.

Tear down the environment with `make stop`
