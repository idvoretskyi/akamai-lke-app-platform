# Token resolution: the default user's token from ~/.config/linode-cli if
# present (local.linode_token in locals.tf), else null, which falls through
# to the provider's own LINODE_TOKEN environment variable lookup.
#
# There are no kubernetes/helm providers: App Platform is installed by LKE
# itself (apl_enabled), not by a helm_release in this repo.
provider "linode" {
  token = local.linode_token
}
