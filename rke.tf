resource "rke_cluster" "k8s" {
  depends_on = [
    outscale_vm.control-planes,
    local_file.control-planes-pem,
    outscale_vm.workers,
    local_file.workers-pem,
    outscale_vm.bastion,
    local_file.bastion-pem,
    local_file.csi_secrets
  ]

  services {
    kube_api {
      extra_args = {
        feature-gates : "CSIVolumeFSGroupPolicy=true" // OSC CSI driver integration
      }
      service_cluster_ip_range = "10.43.0.0/16"
    }

    kube_controller {
      cluster_cidr             = "10.42.0.0/16"
      service_cluster_ip_range = "10.43.0.0/16"
    }

    kubelet {
      extra_args = {
        feature-gates : "CSIVolumeFSGroupPolicy=true" // OSC CSI Driver integration
        read-only-port : "10255" // OSC CSI driver e2e , enable metrics server port
      }
      cluster_dns_server = "10.43.0.10"
    }
  }

  authentication {
    strategy = "x509"
    sans     = concat([for i in range(var.control_plane_count) : format("10.0.1.%d", 10 + i)], ["${outscale_load_balancer.lb-kube-apiserver.dns_name}"])
  }

  kubernetes_version = var.kubernetes_version

  cluster_name = var.cluster_name

  dynamic "cloud_provider" {
    for_each = var.will_install_ccm ? [1] : []
    content {
      name = "external"
    }
  }

  bastion_host {
    address      = outscale_public_ip.bastion.public_ip
    port         = 22
    user         = "outscale"
    ssh_key_path = "${abspath(path.root)}/bastion/bastion.pem"
  }
  dynamic "nodes" {
    for_each = outscale_vm.control-planes
    content {
      address           = nodes.value.private_ip
      hostname_override = nodes.value.private_dns_name
      user              = "outscale"
      role              = ["controlplane", "etcd", "worker"]
      docker_socket     = "/var/run/docker.sock"
      ssh_key_path      = "control-planes/control-plane-${index(outscale_vm.control-planes, nodes.value)}.pem"
    }
  }

  dynamic "nodes" {
    for_each = outscale_vm.workers
    content {
      address           = nodes.value.private_ip
      hostname_override = nodes.value.private_dns_name
      user              = "outscale"
      role              = ["worker"]
      docker_socket     = "/var/run/docker.sock"
      ssh_key_path      = "workers/worker-${index(outscale_vm.workers, nodes.value)}.pem"
    }
  }
}

resource "local_sensitive_file" "kube_config_yaml" {
  filename        = "${path.root}/rke/kube_config_cluster.yml"
  content         = rke_cluster.k8s.kube_config_yaml
  file_permission = "0660"
  provisioner "local-exec" {
    command = "sed -i 's|server:.*$|server: \"https://${outscale_load_balancer.lb-kube-apiserver.dns_name}:6443\"|' ${local_sensitive_file.kube_config_yaml.filename}"
  }
}
