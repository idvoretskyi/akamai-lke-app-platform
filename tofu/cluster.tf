# LKE cluster with Akamai App Platform for LKE (APL) enabled.
#
# APL is installed by LKE itself when apl_enabled = true (the "automatic
# installation" path); there is no helm_release here. The install runs for
# 10 to 15 minutes AFTER this resource reports ready; see scripts/apl-wait.sh.
#
# apl_enabled is write-once: the Linode API only honours it at creation and
# the provider marks it ForceNew. Flipping it replaces the whole cluster.
#
# Exactly one node pool: APL schedules all of its own components (Istio,
# Keycloak, ArgoCD, Harbor, monitoring, ...) and needs no pool labels or
# taints. Adding a second pool for user workloads is an exercise for later.
#
# Autoscaling is intentionally disabled. A fixed node count keeps the monthly
# bill predictable, same philosophy as the sibling akamai-lke-gpu-cluster repo.
resource "linode_lke_cluster" "apl" {
  label       = "${local.cluster_prefix}-lke-apl"
  k8s_version = var.kubernetes_version
  region      = var.region
  tags        = var.tags
  apl_enabled = var.apl_enabled

  pool {
    type  = var.node_type
    count = var.node_count
  }

  control_plane {
    high_availability = var.ha_control_plane

    # The ACL restricts the Kubernetes API only, not the APL console.
    acl {
      enabled = var.enable_control_plane_acl
      addresses {
        ipv4 = var.allowed_kubectl_ips
      }
    }
  }
}
