# Determine cluster name prefix: use provided value or fall back to system username.
locals {
  cluster_prefix = var.cluster_name_prefix != "" ? var.cluster_name_prefix : replace(lower(data.external.username.result.username), "/[^a-z0-9-]/", "-")
}

# Get system username when cluster_name_prefix is not set.
data "external" "username" {
  program = ["sh", "-c", "echo '{\"username\":\"'$(whoami)'\"}'"]
}

# Resolve a Linode API token fallback from the default user in
# ~/.config/linode-cli (linode-cli's own config file), for machines that are
# already `linode-cli configure`'d and don't want a separate
# `export LINODE_TOKEN`. Implemented with plain HCL functions (file/regex),
# NOT a data source: data source results are persisted into OpenTofu state,
# and this repo doesn't want the token to end up there even though state is
# local/gitignored (see AGENTS.md). Locals are never written to state.
#
# Precedence note: because there's no built-in way to read an arbitrary
# environment variable from HCL (only TF_VAR_* via variables), this can't
# check whether LINODE_TOKEN is already set and prefer it. If the
# linode-cli config file resolves to a token, it takes priority here over
# LINODE_TOKEN. For this single-owner lab repo that's an acceptable
# trade-off; if you need to override with a different token, temporarily
# rename ~/.config/linode-cli or update its default user's token instead.
locals {
  linode_cli_config_path  = pathexpand("~/.config/linode-cli")
  linode_cli_config       = fileexists(local.linode_cli_config_path) ? file(local.linode_cli_config_path) : ""
  linode_cli_default_user = try(regex("(?m)^default-user\\s*=\\s*(\\S+)", local.linode_cli_config)[0], null)
  linode_cli_token = local.linode_cli_default_user == null ? null : try(
    regex("(?s)\\[${local.linode_cli_default_user}\\].*?\\ntoken\\s*=\\s*(\\S+)", local.linode_cli_config)[0],
    null
  )

  # null falls through to the linode provider's own LINODE_TOKEN env lookup
  # (e.g. `tofu validate`/`plan` in CI, with no linode-cli config at all,
  # keeps working instead of erroring on an empty token).
  linode_token = local.linode_cli_token != null ? sensitive(local.linode_cli_token) : null
}

locals {
  # CIDRs allowed to talk to each other inside the cluster (nodes + pods).
  # node_cidrs also covers the NodeBalancer backend range, see firewall.tf.
  intra_cluster_cidrs = concat(var.node_cidrs, var.pod_cidrs)

  # Every node's Linode instance ID, for attaching the Cloud Firewall.
  node_instance_ids = flatten([
    for p in linode_lke_cluster.apl.pool : [
      for n in p.nodes : n.instance_id
    ]
  ])
}
