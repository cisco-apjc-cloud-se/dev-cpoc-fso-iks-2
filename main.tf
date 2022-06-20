terraform {
  backend "remote" {
    hostname = "app.terraform.io"
    organization = "mel-ciscolabs-com"
    workspaces {
      name = "dev-cpoc-fso-iks-2"
    }
  }
  required_providers {
    helm = {
      source = "hashicorp/helm"
    }
    kubernetes = {
      source = "hashicorp/kubernetes"
    }
  }
}

### Remote State - Import Kube Config ###
data "terraform_remote_state" "iks-2" {
  backend = "remote"

  config = {
    organization = "mel-ciscolabs-com"
    workspaces = {
      name = "iks-cpoc-syd-demo-2"
    }
  }
}

### Decode Kube Config ###
# Assumes kube_config is passed as b64 encoded
locals {
  kube_config = yamldecode(base64decode(data.terraform_remote_state.iks-2.outputs.kube_config))
}

### Providers ###
provider "kubernetes" {
  # alias = "iks-k8s"
  host                   = local.kube_config.clusters[0].cluster.server
  cluster_ca_certificate = base64decode(local.kube_config.clusters[0].cluster.certificate-authority-data)
  client_certificate     = base64decode(local.kube_config.users[0].user.client-certificate-data)
  client_key             = base64decode(local.kube_config.users[0].user.client-key-data)
}

provider "helm" {
  kubernetes {
    host                   = local.kube_config.clusters[0].cluster.server
    cluster_ca_certificate = base64decode(local.kube_config.clusters[0].cluster.certificate-authority-data)
    client_certificate     = base64decode(local.kube_config.users[0].user.client-certificate-data)
    client_key             = base64decode(local.kube_config.users[0].user.client-key-data)
  }
}

module "fso" {
  source = "github.com/cisco-apjc-cloud-se/terraform-helm-fso"

  # thousandeyes = {
  #   enabled = true
  #   http_tests = {
  #     fso-demo-app = {
  #       name                    = "fso-demo-app"
  #       interval                = 60
  #       url                     = "http://fso-demo-app.cisco.com"
  #       content_regex           = ".*"
  #       network_measurements    = true # 1
  #       mtu_measurements        = true # 1
  #       bandwidth_measurements  = false # 0
  #       bgp_measurements        = true # 1
  #       use_public_bgp          = true # 1
  #       num_path_traces         = 0
  #       agents                  = [
  #         ## "Adelaide, Australia",
  #         # "Auckland, New Zealand",
  #         # "Brisbane, Australia",
  #         "Melbourne, Australia",
  #         # "Melbourne, Australia (Azure australiasoutheast)",
  #         # "Perth, Australia",
  #         "Sydney, Australia",
  #         # "Wellington, New Zealand"
  #       ]
  #     }
  #   }
  # }

  iwo = {
    enabled                 = true
    namespace               = "iwo"
    cluster_name            = "iks-cpoc-syd-demo-2"
    chart_url               = var.iwo_chart_url  # Passed from Workspace Variable
    server_version          = "8.5"
    collector_image_version = "8.5.1"
    dc_image_version        = "1.0.9-110"
  }

  appd = {
    enabled = true
    o2_operator = {
      enabled = true
      operator = {
        enabled = true
      }
      monitor = {
        enabled = true
      }
    }
    legacy = {
      enabled = false
      kubernetes = {
        namespace = "appd"
        release_name = "iks-demo-2" # o2 adds "appdynamics-operator" suffix
      }
      account = {
        name          = var.appd_account_name       # Passed from Workspace Variable
        key           = var.appd_account_key        # Passed from Workspace Variable
        otel_api_key  = var.appd_otel_api_key       # Passed from Workspace Variable
        username      = var.appd_account_username   # Passed from Workspace Variable
        password      = var.appd_account_password   # Passed from Workspace Variable
      }
      metrics_server = {
        install_service = true
      }
      machine_agent = {
        install_service = false
      }
      cluster_agent = {
        install_service = true
        app_name = "iks-cpoc-demo-2"
        monitor_namespace_regex = ".*"
      }
      autoinstrument = {
        enabled = true
        namespace_regex = "coolsox"
        default_appname = "coolsox2-rw"
        java = {
          enabled = true
        }
        dotnetcore = {
          enabled = true
        }
        nodejs = {
          enabled = true
        }
      }
    }
  }
}
