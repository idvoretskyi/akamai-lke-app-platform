terraform {
  required_version = ">= 1.9"

  required_providers {
    linode = {
      source  = "linode/linode"
      version = "~> 4.7"
    }
    external = {
      source  = "hashicorp/external"
      version = "~> 2.0"
    }
  }
}
