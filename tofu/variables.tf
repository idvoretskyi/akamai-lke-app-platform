# ─── Cluster ──────────────────────────────────────────────────────────────────

variable "cluster_name_prefix" {
  description = "Prefix for the LKE cluster name (defaults to system username when empty)"
  type        = string
  default     = ""
}

variable "region" {
  description = "Linode region for the cluster (e.g. 'de-fra-2'). The App Platform docs publish no region list; see the advisory check in checks.tf."
  type        = string
  default     = "de-fra-2" # Frankfurt 2, DE

  validation {
    condition     = can(regex("^[a-z]{2,3}-[a-z]{2,10}[0-9]?(-[0-9]+)?$", var.region))
    error_message = "Region must match the Linode slug format (e.g. 'us-ord', 'eu-west', 'ap-southeast', 'de-fra-2')."
  }
}

variable "kubernetes_version" {
  description = "Kubernetes version for the LKE cluster (format: 'X.Y'). App Platform needs 1.33 or later. List versions with `linode-cli lke versions-list`."
  type        = string
  default     = "1.36"

  validation {
    condition     = can(regex("^1\\.[0-9]+$", var.kubernetes_version)) && try(tonumber(split(".", var.kubernetes_version)[1]) >= 33, false)
    error_message = "kubernetes_version must be in the format '1.Y' with Y >= 33 (App Platform requires Kubernetes 1.33 or later)."
  }
}

variable "tags" {
  description = "Tags to apply to Linode resources"
  type        = list(string)
  default     = ["lke", "apl", "gitops"]
}

# ─── App Platform ─────────────────────────────────────────────────────────────

variable "apl_enabled" {
  description = "Install Akamai App Platform for LKE when the cluster is created. WRITE-ONCE: the Linode API only honours this at creation, and the provider marks it ForceNew, so changing it on an existing cluster DESTROYS and recreates the cluster (and the built-in values repo with it). Requires ha_control_plane = true."
  type        = bool
  default     = true
}

variable "ha_control_plane" {
  description = "Enable the high availability control plane (~$60/month extra). Mandatory when apl_enabled = true. Enabling HA on an existing cluster is irreversible."
  type        = bool
  default     = true

  validation {
    condition     = var.ha_control_plane || !var.apl_enabled
    error_message = "ha_control_plane must be true when apl_enabled = true: App Platform requires the HA control plane (the Linode API rejects the cluster otherwise)."
  }
}

# ─── Node Pool ────────────────────────────────────────────────────────────────
# One fixed-size pool, autoscaling disabled (see cluster.tf). App Platform
# needs at least 3 workers on Dedicated CPU (or Premium) plans with at least
# 4 vCPU / 8 GB each. Shared CPU plans are not supported.

variable "node_type" {
  description = "Linode plan for the worker pool. Dedicated CPU or Premium only (App Platform does not support shared CPU plans). Default g6-dedicated-8 is 8 vCPU / 16 GB (~$144/month per node); g6-dedicated-4 (4 vCPU / 8 GB, ~$72/month) is the documented minimum."
  type        = string
  default     = "g6-dedicated-8"
  # List dedicated/premium plans:
  #   linode-cli linodes types --json | jq -r '.[] | select(.class=="dedicated" or .class=="premium") | .id'

  validation {
    condition     = can(regex("^(g6-dedicated|g7-dedicated|g7-premium|g8-dedicated)-", var.node_type))
    error_message = "node_type must be a Dedicated CPU or Premium plan (g6-dedicated-*, g7-dedicated-*, g7-premium-*, g8-dedicated-*). App Platform does not support shared CPU (g6-standard-*, g6-nanode-*) plans."
  }
}

variable "node_count" {
  description = "Number of worker nodes. Autoscaling is disabled; this is the fixed node count. App Platform requires at least 3."
  type        = number
  default     = 3

  validation {
    condition     = var.node_count >= 1 && (var.node_count >= 3 || !var.apl_enabled)
    error_message = "node_count must be at least 3 when apl_enabled = true (App Platform requirement), and at least 1 otherwise."
  }
}

# ─── Networking ───────────────────────────────────────────────────────────────

variable "allowed_kubectl_ips" {
  description = "IPv4 CIDR ranges allowed to reach the Kubernetes API. Used for both the LKE Control Plane ACL and the Cloud Firewall 443 rule. Neither restricts the App Platform console, which is public behind a NodeBalancer."
  type        = list(string)
  default     = ["0.0.0.0/0"]

  validation {
    condition     = alltrue([for ip in var.allowed_kubectl_ips : can(cidrhost(ip, 0)) && !strcontains(ip, ":")])
    error_message = "Each allowed_kubectl_ips entry must be a valid IPv4 CIDR (e.g. '203.0.113.10/32', '0.0.0.0/0')."
  }
}

variable "enable_control_plane_acl" {
  description = "Enable the LKE Control Plane ACL (default DENY, allowing only allowed_kubectl_ips over IPv4). IPv6 clients are blocked while it is enabled."
  type        = bool
  default     = true
}

variable "node_cidrs" {
  description = "Private CIDRs used by LKE nodes, the Linode control plane and NodeBalancer backends (used for intra-cluster firewall rules). The default covers the full LKE private range, including the NodeBalancer range 192.168.255.0/24."
  type        = list(string)
  default     = ["192.168.128.0/17"]

  validation {
    condition     = alltrue([for cidr in var.node_cidrs : can(cidrhost(cidr, 0))])
    error_message = "Each node_cidrs entry must be a valid CIDR (e.g. '192.168.128.0/17')."
  }
}

variable "pod_cidrs" {
  description = "Pod network CIDRs assigned by the LKE CNI. The default covers the full Linode LKE pod range."
  type        = list(string)
  default     = ["10.2.0.0/16"]

  validation {
    condition     = alltrue([for cidr in var.pod_cidrs : can(cidrhost(cidr, 0))])
    error_message = "Each pod_cidrs entry must be a valid CIDR (e.g. '10.2.0.0/16')."
  }
}

# ─── Kubeconfig ──────────────────────────────────────────────────────────────

variable "merge_kubeconfig" {
  description = "Automatically merge the cluster kubeconfig into ~/.kube/config after deployment. Set false in CI or when managing kubeconfig externally."
  type        = bool
  default     = true
}

# ─── BYO Git ──────────────────────────────────────────────────────────────────

variable "values_repo_name" {
  description = "Name of the private GitHub repo used as the BYO Git target for the APL values repo. Not managed by OpenTofu; only surfaced as an output for scripts/create-values-repo.sh."
  type        = string
  default     = "akamai-lke-app-platform-values"

  validation {
    condition     = can(regex("^[A-Za-z0-9._-]+$", var.values_repo_name))
    error_message = "values_repo_name must be a valid GitHub repository name (letters, digits, '.', '_', '-')."
  }
}
