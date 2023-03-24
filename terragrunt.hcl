terraform {
  source = "${get_repo_root()}/modules/stacks//eks"
}

include "root" {
  path = find_in_parent_folders()
}

// include "vpc" ... # include ControlTower vpc outputs for future use (next rev)

locals {
  env_vars     = read_terragrunt_config(find_in_parent_folders("env.hcl"))
  region_vars  = read_terragrunt_config(find_in_parent_folders("region.hcl"))
  account_vars = read_terragrunt_config(find_in_parent_folders("account.hcl"))
  split_env    = join("-", regex("(sandbox)(.*)", local.account_vars.locals.account_name))
}

generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite"
  contents  = <<EOF
provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    # This requires the awscli to be installed locally where Terraform is executed
    args = ["eks", "get-token", "--cluster-name", module.eks.cluster_id]
  }
}

provider "helm" {
  kubernetes {
    # Configuration options
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      args        = ["eks", "get-token", "--cluster-name", var.cluster_name]
      command     = "aws"
    }
  }
}

provider "kubectl" {
  load_config_file       = false
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    args        = ["eks", "get-token", "--cluster-name", var.cluster_name]
    command     = "aws"
  }
}

EOF
}

inputs = {
  aws = {
    "region" = local.region_vars.locals.aws_region
  }

  domains                    = ["${local.split_env}.onedigitaljsr.com", "onedigitaljsr.com"]
  aws_account_id             = local.account_vars.locals.aws_account_id
  aws_sso_admin_account_role = "AWSReservedSSO_AWSAdministratorAccess_58589dfff654edf7"
  vpc_id                     = local.env_vars.locals.vpc_id
  subnet_ids                 = local.env_vars.locals.private_subnet_ids
  cluster_name               = "onedigital-platform-services-${local.account_vars.locals.account_short_name}"
  env_name                   = local.account_vars.locals.account_short_name
  hosted_zone_ids            = ["arn:aws:route53:::hostedzone/Z0534741195SF5DDVVHW1"]
  instance_type              = "m6a.large"
  cluster_version            = "1.23"

  namespaces = [
    {
      name        = "semi-data-tools"
      app         = "data-tools"
      owner       = "semi"
      managed     = "Terraform"
      annotations = []
      labels      = []
    },
    {
      name        = "semi"
      app         = "any"
      owner       = "semi"
      managed     = "Terraform"
      annotations = []
      labels      = []
    }
  ]

  fargate_profiles = {
    default = {
      name = "default"
      selectors = [
        {
          namespace = "system"
          labels = {
            Application = "backend"
          }
        },
        {
          namespace = "application"
          labels = {
            WorkerType = "fargate"
          }
        },
        {
          namespace = "data-tools"
          labels = {
            Application = "fargate"
          }
        }
      ]

      tags = {
        Owner = "system"
      }

      timeouts = {
        create = "20m"
        delete = "20m"
      }
    }

    secondary = {
      name = "secondary"
      selectors = [
        {
          namespace = "application"
          labels = {
            Environment = local.account_vars.locals.account_short_name
          }
        }
      ]

      # Using specific subnets instead of the subnets supplied for the cluster itself
      subnet_ids = [local.env_vars.locals.private_subnet_ids[2]] // Needs updating to the right subnet

      tags = {
        Owner = "secondary"
      }
    }

    semidatalake = {
      name = "semidatalake"
      selectors = [
        {
          namespace = "data-tools"
          labels = {
            Application = "fargate"
          }
        }
      ]

      tags = {
        Owner = "system"
      }

      timeouts = {
        create = "20m"
        delete = "20m"
      }
    }
  }
}
