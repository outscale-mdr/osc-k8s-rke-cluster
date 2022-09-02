resource "outscale_net" "net" {
  count    = var.public_cloud ? 0 : 1
  ip_range = "10.0.0.0/16"
  tags {
    key   = "OscK8sClusterID/${var.cluster_name}"
    value = "owned"
  }
}
