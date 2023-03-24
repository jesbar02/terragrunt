
terraform {
  required_providers {
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "1.14.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "2.6.0"
    }
  }
}

locals {
  name = "k8s-kms"

  tags = {
    "jsr:product-name"            = "eks-cluster"
    "jsr:proudct-code-name"       = "eks-cluster"
    "jsr:business-unit"           = "digital"
    "jsr:consuming-business-unit" = "shared"
  }
}

# we need data...
data "aws_caller_identity" "current" {}

module "eks" {
  source                          = "terraform-aws-modules/eks/aws"
  version                         = "18.20.2"
  cluster_name                    = var.cluster_name
  cluster_version                 = var.cluster_version
  cluster_enabled_log_types       = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
  cluster_endpoint_private_access = true
  cluster_endpoint_public_access  = true
  cluster_addons = {
    coredns = {
      resolve_conflicts = "OVERWRITE"
    },
    kube-proxy = {
      resolve_conflicts = "OVERWRITE"
    },
    aws-ebs-csi-driver = {
      resolve_conflicts = "OVERWRITE"
    }
  }

  cluster_encryption_config = [{
    provider_key_arn = aws_kms_key.eks.arn
    resources        = ["secrets"]
  }]

  vpc_id     = var.vpc_id
  subnet_ids = var.private_subnet_ids

  enable_irsa = true
  # We manage the config maps as aws does not add admins.
  manage_aws_auth_configmap = true
  aws_auth_roles = [
    {
      rolearn  = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.aws_sso_admin_account_role}"
      username = "system_masters"
      groups   = ["system:masters"]
    },
    {
      rolearn  = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:user/serverless-user"
      username = "system_masters"
      groups   = ["system:masters"]
    },
    {
      rolearn  = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:user/github-actions-user"
      username = "system_masters"
      groups   = ["system:masters"]
    },
  ]
  #aws_auth_users = []
  #aws_auth_accounts = ["${var.aws_account_id}"]
  # set below to false otherwise tf will throw an error aaabout the prefix being over 38 characters.
  iam_role_use_name_prefix               = false
  node_security_group_use_name_prefix    = false
  cluster_security_group_use_name_prefix = false
  /*oidc_providers = {
        ex = {
            provider_arn               = module.eks.oidc_provider_arn
            namespace_service_accounts = ["kube-system:cluster-autoscaler"]
        }
    }*/

  eks_managed_node_group_defaults = {
    force_update_version         = true
    desired_size                 = 1
    min_size                     = 0
    max_size                     = 10
    ebs_optimized                = true
    capacity_type                = "ON_DEMAND"
    iam_role_additional_policies = ["arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"]
    block_device_mappings = {
      root = {
        device_name = "/dev/xvda"
        ebs = {
          volume_size           = 20
          volume_type           = "gp3"
          encrypted             = true
          kms_key_id            = aws_kms_key.ebs.arn
          delete_on_termination = true
        }
      }
    }
  }

  eks_managed_node_groups = {
    "onedigital-platform-services-worker-a" = {
      desired_size   = 1
      ami_type       = "AL2_x86_64"
      platform       = "linux"
      instance_types = [var.instance_type]
      subnet_ids     = [var.private_subnet_ids[0]]
      labels = {
        network = "private"
      }
      use_name_prefix          = false
      iam_role_use_name_prefix = false
    }

    "onedigital-platform-services-worker-b" = {
      desired_size   = 1
      ami_type       = "AL2_x86_64"
      platform       = "linux"
      instance_types = [var.instance_type]
      subnet_ids     = [var.private_subnet_ids[1]]
      labels = {
        network = "private"
      }
      use_name_prefix          = false
      iam_role_use_name_prefix = false
    }

    "onedigital-platform-services-worker-c" = {
      desired_size   = 1
      ami_type       = "AL2_x86_64"
      platform       = "linux"
      instance_types = [var.instance_type]
      subnet_ids     = [var.private_subnet_ids[2]]
      labels = {
        network = "private"
      }
      use_name_prefix          = false
      iam_role_use_name_prefix = false
    }
  }

  node_security_group_additional_rules = {
    ingress_self_all = {
      from_port = 0
      to_port   = 0
      protocol  = "-1"
      type      = "ingress"
      self      = true
    }
    ingress_cluster_all = {
      from_port                     = 0
      to_port                       = 0
      protocol                      = "-1"
      type                          = "ingress"
      source_cluster_security_group = true
    }
    ingress_cluster_vpn = {
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      type        = "ingress"
      cidr_blocks = ["10.229.0.0/16", "10.220.0.0/16", "10.222.0.0/16", "10.16.0.0/14"]
    }
    ingress_node_port_tcp = {
      from_port        = 0
      to_port          = 0
      protocol         = "-1"
      type             = "ingress"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = ["::/0"]
    }
    egress_all = {
      from_port        = 0
      to_port          = 0
      protocol         = "-1"
      type             = "egress"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = ["::/0"]
    }
  }

  fargate_profiles = var.fargate_profiles
  tags             = local.tags
}
/*
data "aws_eks_cluster" "default" {
  name = var.cluster_name
}

data "aws_eks_cluster_auth" "default" {
  name = var.cluster_name
} */

module "cert_manager" {
  depends_on                             = [module.eks]
  source                                 = "terraform-iaac/cert-manager/kubernetes"
  version                                = "2.4.2"
  cluster_issuer_email                   = "admin@jsr-nahq.com"
  cluster_issuer_name                    = "cert-manager-global"
  cluster_issuer_private_key_secret_name = "cert-manager-private-key"
} /**/

resource "aws_kms_key" "eks" {
  description             = var.env_name
  deletion_window_in_days = 7
  enable_key_rotation     = true

  tags = local.tags
}

module "iam_eks_role" {
  source    = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  role_name = "eks-${var.env_name}"

  oidc_providers = {
    one = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system"]
    }
    two = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system"]
    }
  }
}

module "vpc_cni_irsa_role" {
  source = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"

  role_name = "eks-${var.env_name}-vpc-cni"

  attach_vpc_cni_policy = true
  vpc_cni_enable_ipv4   = true

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-node"]
    }
  }
}

module "external_dns_irsa_role" {
  source = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"

  role_name                     = "external_dns_controller"
  attach_external_dns_policy    = true
  external_dns_hosted_zone_arns = var.hosted_zone_ids


  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:external-dns"]
    }
  }
}

module "external_dns_public" {
  depends_on = [module.eks]
  source     = "lablabs/eks-external-dns/aws"

  cluster_identity_oidc_issuer     = module.eks.oidc_provider
  cluster_identity_oidc_issuer_arn = module.eks.oidc_provider_arn
  irsa_role_name_prefix            = "external-dns-irsa-public"

  helm_chart_version   = "6.1.0"
  helm_release_name    = "external-dns-public"
  service_account_name = "external-dns-public"

  values = yamlencode({
    "LogLevel" : "debug"
    "provider" : "aws"
    "registry" : "txt"
    "txtOwnerId" : "eks-${var.env_name}"
    "txtPrefix" : "external-dns-public-"
    "policy" : "sync"
    "aws" : {
      "zoneType" : "public"
    }
    "annotationFilter" : "alb.ingress.kubernetes.io/scheme in (internet-facing)"
    "domainFilters" : var.domains
    "publishInternalServices" : "true"
    "triggerLoopOnEvent" : "true"
    "interval" : "5s"
  })

}

module "external_dns_private" {
  depends_on = [module.eks]
  source     = "lablabs/eks-external-dns/aws"

  cluster_identity_oidc_issuer     = module.eks.oidc_provider
  cluster_identity_oidc_issuer_arn = module.eks.oidc_provider_arn
  irsa_role_name_prefix            = "external-dns-irsa-private"
  service_account_name             = "external-dns-private"


  helm_chart_version = "6.1.0"
  helm_release_name  = "external-dns-private"

  values = yamlencode({
    "LogLevel" : "debug"
    "provider" : "aws"
    "registry" : "txt"
    "txtOwnerId" : "eks-${var.env_name}"
    "txtPrefix" : "external-dns-private-"
    "policy" : "sync"
    "aws" : {
      "zoneType" : "private"
    }
    "annotationFilter" : "alb.ingress.kubernetes.io/scheme in (internal)"
    "domainFilters" : var.domains
    "publishInternalServices" : "true"
    "triggerLoopOnEvent" : "true"
    "interval" : "5s"
  })

}

module "lb_controller_helm" {
  depends_on = [module.eks]
  source     = "lablabs/eks-load-balancer-controller/aws"

  enabled           = true
  argo_enabled      = false
  argo_helm_enabled = false

  cluster_name                     = module.eks.cluster_id
  cluster_identity_oidc_issuer     = module.eks.oidc_provider
  cluster_identity_oidc_issuer_arn = module.eks.oidc_provider_arn

  helm_release_name = "aws-lbc-helm"
  namespace         = "kube-system"

  values = yamlencode({
    "podLabels" : {
      "app" : "aws-lbc-helm"
    }
  })

  helm_timeout = 240
  helm_wait    = true
}

# Add our namespaces..
resource "kubernetes_namespace" "namespaces" {
  for_each = { for k, v in var.namespaces : k => v } //loop over the namespaces
  metadata {
    name = each.value.name
    annotations = {
      for annotation in each.value.annotations : annotation.label => annotation.value
    }
    labels = {
      for label in each.value.labels : label.label => label.value
    }
  }
}

# for ebs encryption...
resource "aws_kms_key" "ebs" {
  description             = "Customer managed key to encrypt self managed node group volumes"
  deletion_window_in_days = 7
  policy                  = data.aws_iam_policy_document.ebs.json
}

data "aws_iam_policy_document" "ebs" {
  # Copy of default KMS policy that lets you manage it
  statement {
    sid       = "Enable IAM User Permissions"
    actions   = ["kms:*"]
    resources = ["*"]

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
  }

  # Required for EKS
  statement {
    sid = "Allow service-linked role use of the CMK"
    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:DescribeKey"
    ]
    resources = ["*"]

    principals {
      type = "AWS"
      identifiers = [
        "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/aws-service-role/autoscaling.amazonaws.com/AWSServiceRoleForAutoScaling", # required for the ASG to manage encrypted volumes for nodes
        module.eks.cluster_iam_role_arn,                                                                                                            # required for the cluster / persistentvolume-controller to create encrypted PVCs
      ]
    }
  }

  statement {
    sid       = "Allow attachment of persistent resources"
    actions   = ["kms:CreateGrant"]
    resources = ["*"]

    principals {
      type = "AWS"
      identifiers = [
        "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/aws-service-role/autoscaling.amazonaws.com/AWSServiceRoleForAutoScaling", # required for the ASG to manage encrypted volumes for nodes
        module.eks.cluster_iam_role_arn,                                                                                                            # required for the cluster / persistentvolume-controller to create encrypted PVCs
      ]
    }

    condition {
      test     = "Bool"
      variable = "kms:GrantIsForAWSResource"
      values   = ["true"]
    }
  }
}

# EBS storage class for kubernetes deployments
resource "kubernetes_storage_class_v1" "ebs-sc" {
  metadata {
    name = "ebs-sc"
  }
  storage_provisioner = "ebs.csi.aws.com"
  volume_binding_mode = "WaitForFirstConsumer"
  parameters = {
    encrypted = "true"
    kmsKeyId  = aws_kms_key.ebs.arn
  }
}

resource "aws_iam_policy" "node_additional" {
  name        = "${var.env_name}-additional"
  description = "Example usage of node additional policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "ec2:AttachVolume",
          "ec2:CreateSnapshot",
          "ec2:CreateTags",
          "ec2:CreateVolume",
          "ec2:DeleteSnapshot",
          "ec2:DeleteTags",
          "ec2:DeleteVolume",
          "ec2:DescribeAvailabilityZones",
          "ec2:DescribeInstances",
          "ec2:DescribeSnapshots",
          "ec2:DescribeTags",
          "ec2:DescribeVolumes",
          "ec2:DescribeVolumesModifications",
          "ec2:DetachVolume",
          "ec2:ModifyVolume",
          "kms:CreateGrant",
          "kms:Decrypt",
          "kms:Describe*",
          "kms:Encrypt",
          "kms:GenerateDataKey*",
          "kms:ReEncrypt*"
        ]
        Effect   = "Allow"
        Resource = "*"
      },
    ]
  })

  tags = local.tags
}

resource "aws_iam_role_policy_attachment" "additional" {
  for_each = module.eks.eks_managed_node_groups

  policy_arn = aws_iam_policy.node_additional.arn
  role       = each.value.iam_role_name
}

