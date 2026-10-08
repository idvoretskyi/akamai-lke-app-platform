# ─── Cluster ──────────────────────────────────────────────────────────────────

output "cluster_id" {
  description = "The ID of the LKE cluster"
  value       = linode_lke_cluster.apl.id
}

output "cluster_label" {
  description = "The label of the LKE cluster"
  value       = linode_lke_cluster.apl.label
}

output "region" {
  description = "The region where the cluster is deployed"
  value       = linode_lke_cluster.apl.region
}

output "kubernetes_version" {
  description = "The Kubernetes version running on the cluster"
  value       = linode_lke_cluster.apl.k8s_version
}

output "api_endpoints" {
  description = "The API endpoints for the cluster"
  value       = linode_lke_cluster.apl.api_endpoints
}

output "kubectl_context" {
  description = "The kubectl context name for this cluster"
  value       = "lke${linode_lke_cluster.apl.id}-ctx"
}

output "kubeconfig" {
  description = "Base64-encoded kubeconfig for the cluster"
  value       = linode_lke_cluster.apl.kubeconfig
  sensitive   = true
}

output "firewall_id" {
  description = "The ID of the firewall protecting the cluster"
  value       = linode_firewall.lke_firewall.id
}

# ─── App Platform ─────────────────────────────────────────────────────────────
# The APL console URL is not exposed by the Linode API or the provider; it
# lives in the `welcome` ConfigMap in the cluster. scripts/apl-wait.sh prints it.

output "apl_enabled" {
  description = "Whether App Platform was requested at cluster creation"
  value       = linode_lke_cluster.apl.apl_enabled
}

output "values_repo_name" {
  description = "Name of the BYO Git values repo (consumed by scripts/create-values-repo.sh)"
  value       = var.values_repo_name
}

output "next_steps" {
  description = "What to run after `tofu apply`"
  value       = <<-EOT
    App Platform installs for 10 to 15 minutes after the cluster is ready.
    From the tofu/ directory:

      1. scripts/apl-wait.sh           # waits for the install, prints the portal URL
      2. scripts/apl-credentials.sh    # prints the initial admin username/password
      3. Log in, change the password, finish the Object Storage wizard
         (needs a Linode PAT with Object Storage read/write).
      4. make -C ../examples/gitops-hello clone sync push status
  EOT
}
