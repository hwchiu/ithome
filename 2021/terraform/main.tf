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
  access_key = "xxxxxxxx"
  secret_key = "xxxxxxxxxxxxxxxxxxxxxxx"
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

data "rancher2_project" "system" {
    cluster_id = "c-z8j6q"
    name = "myApplication"
}

resource "rancher2_catalog" "dashboard-global" {
  name = "dashboard-terraform"
  url = "https://kubernetes.github.io/dashboard/"
  version = "helm_v3"
}

resource "rancher2_namespace" "dashboard" {
  name = "dashboard-terraform"
  project_id = data.rancher2_project.system.id
}

resource "rancher2_app" "dashboard" {
  catalog_name = "dashboard-terraform"
  name = "dashboard-terraform"
  project_id = data.rancher2_project.system.id
  template_name = "kubernetes-dashboard"
  template_version = "4.5.0"
  target_namespace = rancher2_namespace.dashboard.id
  depends_on       = [rancher2_namespace.dashboard, rancher2_catalog.dashboard-global]
}

resource "rancher2_catalog_v2" "dashboard-global-app" {
  name = "dashboard-terraform"
  cluster_id = "c-z8j6q"
  url = "https://kubernetes.github.io/dashboard/"
}

resource "rancher2_namespace" "dashboard-app" {
  name = "dashboard-terraform-app"
  project_id = data.rancher2_project.system.id
}

resource "rancher2_app_v2" "dashboard-app" {
  cluster_id = "c-z8j6q"
  name = "k8s-dashboard-app-terraform"
  namespace = rancher2_namespace.dashboard-app.id
  repo_name = "dashboard-terraform"
  chart_name = "kubernetes-dashboard"
  chart_version = "4.5.0"
  depends_on       = [rancher2_namespace.dashboard-app, rancher2_catalog_v2.dashboard-global-app]
}
