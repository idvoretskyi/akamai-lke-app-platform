# Firewall for LKE cluster.
#
# App Platform exposes its ingress and console through a Linode NodeBalancer,
# which reaches the nodes' NodePorts over the private network from
# 192.168.255.0/24. The intra-cluster rules below admit that range because
# var.node_cidrs (default 192.168.128.0/17) contains it. Removing or narrowing
# those rules breaks the APL portal; checks.tf warns if node_cidrs stops
# covering the NodeBalancer range.
resource "linode_firewall" "lke_firewall" {
  label = "${local.cluster_prefix}-lke-apl-firewall"
  tags  = var.tags

  inbound {
    label    = "allow-kubectl"
    action   = "ACCEPT"
    protocol = "TCP"
    ports    = "443"
    ipv4     = var.allowed_kubectl_ips
  }

  # Allow all intra-cluster TCP: control-plane→kubelet (10250), API server→webhooks (443/9443),
  # node↔node, pod↔pod, NodeBalancer→NodePort. Without this the Linode Cloud Firewall drops
  # these packets, webhook admission times out and kubectl logs/exec fail.
  inbound {
    label    = "allow-intra-cluster-tcp"
    action   = "ACCEPT"
    protocol = "TCP"
    ports    = "1-65535"
    ipv4     = local.intra_cluster_cidrs
  }

  inbound {
    label    = "allow-intra-cluster-udp"
    action   = "ACCEPT"
    protocol = "UDP"
    ports    = "1-65535"
    ipv4     = local.intra_cluster_cidrs
  }

  inbound_policy  = "DROP"
  outbound_policy = "ACCEPT"

  linodes = local.node_instance_ids
}
