module "eks-metrics-server" {
  depends_on        = [module.eks]
  source            = "lablabs/eks-metrics-server/aws"
  version           = "1.0.0"
  enabled           = true
  argo_enabled      = false
  argo_helm_enabled = false

  helm_release_name = "metrics-server"
  namespace         = "kube-system"

  values = yamlencode({
    "podLabels" : {
      "app" : "metrics-server"
    }
  })

  settings = {
    "apiService.create" = "true"
  }

  helm_timeout = 240
  helm_wait    = true
}

