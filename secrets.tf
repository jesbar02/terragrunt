resource "helm_release" "secret_storage_csi_driver" {
  depends_on = [module.eks]
  chart      = "secrets-store-csi-driver"
  repository = "https://kubernetes-sigs.github.io/secrets-store-csi-driver/charts"
  name       = "secrets-store-csi-driver"
  version    = "1.2.2"
  atomic     = true

  set {
    name  = "syncSecret.enabled"
    value = "true"
  }

  set {
    name  = "grpcSupportedProviders"
    value = "aws"
  }
}

resource "kubernetes_service_account" "batch-disposition-service-account" {
  depends_on = [module.eks]
  metadata {
    name      = "csi-secrets-store-provider-aws"
    namespace = "kube-system"
    annotations = {
      "eks.amazonaws.com/role-arn" = "${tostring(module.iam_eks_role.iam_role_arn)}"
    }
  }
  automount_service_account_token = true
}

resource "kubernetes_cluster_role" "csi-secrets-store-provider-aws-cluster-role" {
  depends_on = [module.eks]
  metadata {
    name = "csi-secrets-store-provider-aws-cluster-role"
  }

  rule {
    api_groups = [""]
    resources  = ["serviceaccounts/token"]
    verbs      = ["create"]
  }
  rule {
    api_groups = [""]
    resources  = ["serviceaccounts"]
    verbs      = ["get"]
  }
  rule {
    api_groups = [""]
    resources  = ["pods"]
    verbs      = ["get"]
  }
  rule {
    api_groups = [""]
    resources  = ["nodes"]
    verbs      = ["get"]
  }
}

resource "kubernetes_cluster_role_binding_v1" "csi-secrets-store-provider-aws-cluster-rolebinding" {
  metadata {
    name = "csi-secrets-store-provider-aws-cluster-rolebinding"
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "csi-secrets-store-provider-aws-cluster-role"
  }
  subject {
    kind      = "ServiceAccount"
    name      = "csi-secrets-store-provider-aws"
    namespace = "kube-system"
  }
}

resource "kubernetes_daemon_set_v1" "csi-secrets-store-provider-aws" {
  depends_on = [module.eks]
  metadata {
    name      = "csi-secrets-store-provider-aws"
    namespace = "kube-system"
    labels = {
      app = "csi-secrets-store-provider-aws"
    }
  }

  spec {
    strategy {
      type = "RollingUpdate"
    }
    selector {
      match_labels = {
        app = "csi-secrets-store-provider-aws"
      }
    }

    template {
      metadata {
        labels = {
          app = "csi-secrets-store-provider-aws"
        }
      }

      spec {
        service_account_name = "csi-secrets-store-provider-aws"
        container {
          image             = "public.ecr.aws/aws-secrets-manager/secrets-store-csi-driver-provider-aws:1.0.r2-6-gee95299-2022.04.14.21.07"
          name              = "provider-aws-installer"
          image_pull_policy = "Always"
          args              = ["--provider-volume=/etc/kubernetes/secrets-store-csi-providers"]

          resources {
            limits = {
              cpu    = "50m"
              memory = "100Mi"
            }
            requests = {
              cpu    = "50m"
              memory = "100Mi"
            }
          }

          volume_mount {
            name       = "providervol"
            mount_path = "/etc/kubernetes/secrets-store-csi-providers"
          }
          volume_mount {
            name              = "mountpoint-dir"
            mount_path        = "/var/lib/kubelet/pods"
            mount_propagation = "HostToContainer"
          }
        }

        volume {
          name = "providervol"
          host_path {
            path = "/etc/kubernetes/secrets-store-csi-providers"
          }
        }

        volume {
          name = "mountpoint-dir"
          host_path {
            path = "/var/lib/kubelet/pods"
            type = "DirectoryOrCreate"
          }
        }

        node_selector = {
          "kubernetes.io/os" = "linux"
        }
      }
    }
  }
}

