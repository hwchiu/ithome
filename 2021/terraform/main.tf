terraform {
  required_providers {
    rancher2 = {
      source = "rancher/rancher2"
      version = "1.17.0"
    }
  }
}

provider "rancher2" {
  api_url    = "https://rancher.hwchiu.com"
  access_key = "token-xxxx"
  secret_key = "xxxxxxxxxxxxxxxxx"
}

resource "rancher2_cluster_template" "foo" {
  name = "ithome_terraforn"
  template_revisions {
    name = "V1"
    cluster_config {
      rke_config {
        network {
          plugin = "canal"
        }
        services {
          etcd {
            creation = "6h"
            retention = "24h"
          }
        }
        upgrade_strategy {
          drain = true
          max_unavailable_worker = "20%"
        }
      }
    }
    default = true
  }
  description = "Terraform cluster template foo"
}
