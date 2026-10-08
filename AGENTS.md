# AGENTS.md

OpenTofu IaC repo, **no application code**. All config lives in `tofu/` (a
single root module, no `modules/` directory: App Platform is installed by LKE
itself through `apl_enabled`, not by Helm). The CLI is `tofu` (OpenTofu >=
1.9), **not** `terraform`. When code and prose disagree, the `.tf` files and
`tofu/tofu.tfvars.example` are the source of truth.

## Commands (run from `tofu/`)

- Always run `tofu fmt -recursive` before committing. CI gate
  `tofu fmt -check -recursive` fails on any unformatted file.
- CI validates with no backend and no cloud creds:
  `tofu init -backend=false` then `tofu validate -no-color`.
- Other CI gates (`.github/workflows/ci.yml`): `tflint --recursive`
  (config `tofu/.tflint.hcl`), `shellcheck` on `tofu/scripts/`, an
  `examples` job (yamllint on `examples/`, `make -n -C
  examples/gitops-hello sync push`), Trivy IaC scan on `tofu/` (fails on
  HIGH/CRITICAL), markdownlint on `**/*.md` (config `.markdownlint.json`).
- After `tofu apply`: `scripts/apl-wait.sh` (polls up to 25 min, prints the
  portal URL), then `scripts/apl-credentials.sh`.
- GitOps loop: `make -C examples/gitops-hello clone sync push status`
  (needs a finished App Platform install).

## Local apply quirks

- Auth: the `linode` provider resolves its token from the default user in
  `~/.config/linode-cli` if present (parsed with plain HCL `file()`/`regex()`
  in `locals.tf`, deliberately not a data source, so it's never persisted to
  state), else falls back to its own `LINODE_TOKEN` environment variable
  lookup. The linode-cli config takes priority over `LINODE_TOKEN` when both
  are present. There is no tfvars entry for the token.
- `tofu apply` runs a `local-exec` that merges the kubeconfig into
  `~/.kube/config` (requires `kubectl` on PATH). Set `merge_kubeconfig = false`
  to skip (CI / externally managed kubeconfig).
- `tofu apply` returns when the cluster is ready, but App Platform keeps
  installing for another 10 to 15 minutes. Nothing in OpenTofu waits for it;
  `apl-wait.sh` does.
- Git-ignored: `*.tfvars`, `*.tfstate*`, `kubeconfig*.yaml`, `.values/`.
  `.terraform.lock.hcl` **is tracked**; do not gitignore it. Put real config
  in `tofu/tofu.tfvars` (copy from `tofu.tfvars.example`).

## Non-obvious constraints (easy to break)

- `apl_enabled` is **write-once**. The Linode API only honours it at creation
  and the provider marks it ForceNew: changing it replaces the cluster.
- The HA control plane is mandatory with App Platform. Enforced as a hard
  variable validation on `ha_control_plane`, not a `check`.
- Dedicated CPU or Premium plans only (`node_type` regex); shared CPU plans
  are unsupported. At least 4 vCPU / 8 GB per node (advisory `check`).
- At least 3 nodes when `apl_enabled = true` (validation on `node_count`).
  One fixed pool, autoscaling intentionally disabled.
- The APL console and ingress sit behind a Linode NodeBalancer that reaches
  nodes from `192.168.255.0/24`. The `allow-intra-cluster-*` firewall rules
  admit it via `node_cidrs`; narrowing them breaks the portal. The Control
  Plane ACL restricts the Kubernetes API only, never the console.
- Neither the Linode API nor the provider exposes the App Platform console
  URL. It lives in the `welcome` ConfigMap in `apl-operator`; do not invent
  an output for it.
- Directories prefixed `apl-` in the values repo (`apl-secrets`, `apl-users`)
  are operator-owned. Never write to them; the example Makefile refuses to.
- Destroying the cluster destroys the built-in Git server and the values repo
  history. Only the BYO Git switch to an external repo preserves it.
- The BYO Git switch is **UI-only** (Platform view > Settings > Git). There
  is no API or IaC path; `scripts/create-values-repo.sh` only prepares the
  empty private repo.
- The first portal login forces a password change and opens the Object
  Storage wizard, which needs a Linode PAT with Object Storage read/write
  (not stored by the platform).
- App Platform creates at least 11 Block Storage volumes. Pods stuck
  `Pending` with unbound PVCs during install usually mean the account Volume
  limit was hit.
- `checks.tf` uses OpenTofu `check` blocks (>= 1.9) for **non-blocking**
  advisory warnings: undersized plan, `0.0.0.0/0` in `allowed_kubectl_ips`,
  `node_cidrs` not covering the NodeBalancer range, and a region outside the
  point-in-time list of regions with LKE, NodeBalancers and Block Storage.

## Conventions

- Single owner `@idvoretskyi` (CODEOWNERS). CI runs on PRs to `main`.
- Dependabot commit prefixes: `deps(terraform)`, `deps(actions)`.
- Every commit needs a DCO `Signed-off-by` trailer (the DCO check fails the
  PR otherwise): commit with `git commit -s`, or fix a branch with
  `git rebase --signoff <base>`. The example Makefile also signs off commits
  it makes in the values repo.
- Prose style: no em dashes.
