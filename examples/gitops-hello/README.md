# GitOps hello

A minimal App Platform GitOps loop: copy plain Kubernetes manifests into the
APL `values` repo, push, and let ArgoCD reconcile them into the cluster.

## How the values repo maps to ArgoCD

Every directory under `env/manifests/namespaces/<ns>/` becomes one ArgoCD
Application that deploys into namespace `<ns>` (created if missing), and the
subdirectories below it (`deployment/`, `service/`) are only for organisation.
Cluster-scoped resources such as ClusterRoles and CRDs go under
`env/manifests/global/<kind>/`, which is a single Application with no target
namespace. Directories prefixed `apl-` (`apl-secrets`, `apl-users`) are owned
by the App Platform operator, and this Makefile refuses to write to them.

```text
manifests/                      ->  .values/env/manifests/
  namespaces/hello/                   namespaces/hello/          (Application "hello")
    deployment/deployment.yaml
    service/service.yaml
  global/clusterrole/                 global/clusterrole/        (global Application)
    hello-readonly.yaml
```

## Prerequisites

- App Platform installed (`tofu/scripts/apl-wait.sh` succeeded).
- `kubectl` pointed at the cluster, plus `git` and `rsync`.

## The loop

```bash
make clone    # clone or pull the values repo into ./.values (git-ignored)
make sync     # copy hello/ and the ClusterRole into .values/env/manifests
make push     # git commit -s and push; ArgoCD picks it up in a few minutes
make status   # ArgoCD Applications plus `kubectl get all -n hello`
```

Edit anything under `manifests/` and repeat `make sync push`. Reach the app
with:

```bash
kubectl port-forward -n hello svc/hello 8080:80
curl -s localhost:8080 | head -n 4
```

`make clean` removes the example from the values repo and pushes; ArgoCD
prunes the namespace contents and the ClusterRole.

After the BYO Git switch (see the top-level README), point `clone` at the
external repo:

```bash
rm -rf .values
VALUES_REPO_URL=https://github.com/<owner>/<values-repo>.git make clone
```

## Not covered here

No Ingress: exposing services through App Platform's Istio ingress and teams
is a separate topic. The ArgoCD namespace is not documented by App Platform,
so `make status` searches all namespaces.
