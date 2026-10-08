# Advisory (non-blocking) checks: warnings only, never fail `tofu apply`.
# See AGENTS.md: OpenTofu `check` blocks (>= 1.9).
#
# Hard requirements of App Platform (HA control plane, >= 3 nodes, dedicated
# or premium plans only, Kubernetes >= 1.33) are variable validations in
# variables.tf, not checks here: the Linode API would reject or misbuild the
# cluster, so they are treated as real misconfigurations.

# Size of the smaller dedicated/premium plans, so a plan below the App
# Platform minimum (4 vCPU / 8 GB) is flagged. Plans not listed are larger
# than 16 GB and are skipped. Point-in-time list, re-check with:
#   linode-cli linodes types --json | jq -r '.[] | select(.class=="dedicated" or .class=="premium") | "\(.id) \(.vcpus) \(.memory)"'
locals {
  small_plan_sizes = {
    "g6-dedicated-2"    = { vcpus = 2, mem_gib = 4 }
    "g6-dedicated-4"    = { vcpus = 4, mem_gib = 8 }
    "g6-dedicated-8"    = { vcpus = 8, mem_gib = 16 }
    "g7-premium-2"      = { vcpus = 2, mem_gib = 4 }
    "g7-premium-4"      = { vcpus = 4, mem_gib = 8 }
    "g7-premium-8"      = { vcpus = 8, mem_gib = 16 }
    "g7-dedicated-4-2"  = { vcpus = 2, mem_gib = 4 }
    "g7-dedicated-8-4"  = { vcpus = 4, mem_gib = 8 }
    "g7-dedicated-16-8" = { vcpus = 8, mem_gib = 16 }
    "g8-dedicated-4-2"  = { vcpus = 2, mem_gib = 4 }
    "g8-dedicated-8-2"  = { vcpus = 2, mem_gib = 8 }
    "g8-dedicated-8-4"  = { vcpus = 4, mem_gib = 8 }
    "g8-dedicated-16-4" = { vcpus = 4, mem_gib = 16 }
    "g8-dedicated-16-8" = { vcpus = 8, mem_gib = 16 }
  }
  node_plan_size = lookup(local.small_plan_sizes, var.node_type, null)
}

# 8 GB / 4 vCPU is the documented minimum; 16 GB (the g6-dedicated-8 default)
# is the comfortable size for the full APL stack.
check "node_plan_meets_apl_minimum" {
  assert {
    condition     = !var.apl_enabled || local.node_plan_size == null || (local.node_plan_size.mem_gib >= 8 && local.node_plan_size.vcpus >= 4)
    error_message = "node_type '${var.node_type}' is below the App Platform minimum of 4 vCPU / 8 GB per node. The install will likely fail or leave pods Pending."
  }
}

check "kubectl_open_to_world" {
  assert {
    condition     = !contains(var.allowed_kubectl_ips, "0.0.0.0/0")
    error_message = "allowed_kubectl_ips contains 0.0.0.0/0: the Kubernetes API is reachable from anywhere. Lock it down (e.g. [\"203.0.113.10/32\"]) for anything beyond a short-lived lab."
  }
}

# The APL NodeBalancer reaches node NodePorts from 192.168.255.0/24. If no
# node_cidrs entry contains that range, the firewall drops NodeBalancer
# traffic and the portal and all APL ingress become unreachable.
locals {
  nodebalancer_backend_cidr = "192.168.255.0/24"
  nodebalancer_range_covered = anytrue([
    for c in var.node_cidrs : try(
      tonumber(split("/", c)[1]) <= 24 &&
      cidrhost(c, 0) == cidrhost("192.168.255.0/${split("/", c)[1]}", 0),
      false
    )
  ])
}

check "node_cidrs_cover_nodebalancer" {
  assert {
    condition     = local.nodebalancer_range_covered
    error_message = "No node_cidrs entry contains the NodeBalancer backend range ${local.nodebalancer_backend_cidr}. The firewall will drop NodeBalancer health checks and traffic, breaking the App Platform portal and ingress."
  }
}

# The App Platform docs publish no region list. These are the core regions
# that offered Kubernetes, NodeBalancers and Block Storage when this was
# written. Point-in-time list, re-check with:
#   linode-cli regions list --json --all-rows | jq -r '.[] | select(.site_type=="core") | select((.capabilities|index("Kubernetes")) and (.capabilities|index("NodeBalancers")) and (.capabilities|index("Block Storage"))) | .id'
locals {
  apl_capable_regions = [
    "ap-northeast", "ap-south", "ap-southeast", "ap-west", "au-mel", "br-gru",
    "ca-central", "de-fra-2", "es-mad", "eu-central", "eu-west", "fr-par",
    "fr-par-2", "gb-lon", "id-cgk", "in-bom-2", "in-maa", "it-mil", "jp-osa",
    "jp-tyo-3", "nl-ams", "se-sto", "sg-sin-2", "us-central", "us-east",
    "us-iad", "us-iad-2", "us-lax", "us-mia", "us-ord", "us-sea",
    "us-southeast", "us-west",
  ]
}

check "region_supports_apl_dependencies" {
  assert {
    condition     = contains(local.apl_capable_regions, var.region)
    error_message = "Region '${var.region}' is not in the known list of regions offering Kubernetes, NodeBalancers and Block Storage (all needed by App Platform). Verify with `linode-cli regions list`."
  }
}
