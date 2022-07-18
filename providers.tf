terraform {
  required_providers {
    outscale = {
      source  = "outscale-dev/outscale"
      version = "0.5.0"
    }
    shell = {
      source  = "scottwinkler/shell"
      version = "1.7.7"
    }
    rke = {
      source  = "rancher/rke"
      version = "1.3.1"
    }

  }
}

provider "outscale" {
  access_key_id = var.access_key_id
  secret_key_id = var.secret_key_id
  region        = var.region
}
