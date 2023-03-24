/*module "cloudwatch_logs" {
  source = "DNXLabs/eks-cloudwatch-logs/aws"

  enabled = true

  cluster_name                     = module.eks.cluster_id
  cluster_identity_oidc_issuer     = module.eks.cluster_oidc_issuer_url
  cluster_identity_oidc_issuer_arn = module.eks.oidc_provider_arn
  worker_iam_role_name             = module.eks.iam_eks_role
  region                           = data.aws_region.current.name
}*/

module "eks-cloudwatch" {
  source                  = "git::https://github.com/kabisa/terraform-aws-eks-cloudwatch.git"
  depends_on              = [module.eks]
  account_id              = var.aws_account_id
  eks_cluster_name        = module.eks.cluster_id
  enable_cloudwatch_agent = true
  enable_fluentbit        = true
  oidc_host_path          = split("://", module.eks.cluster_oidc_issuer_url)[1]
  region                  = "us-east-1"
}
