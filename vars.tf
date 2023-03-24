variable "private_subnet_ids" {
  description = "List of private subnet ids for the EKS cluster"
  type        = list(string)
  default     = []
}

variable "vpc_id" {
  description = "VPC id for the EKS cluster"
  type        = string
  default     = ""
}

variable "cluster_name" {
  description = "Name of the cluster"
  type        = string
  default     = "setme"
}

variable "instance_type" {
  description = "Instance type e.g. t3a.large"
  type        = string
  default     = "t3a.large"
}

variable "env_name" {
  description = "Env name for tagging/labeling."
  type        = string
  default     = ""
}

variable "hosted_zone_ids" {
  description = "Hosted zone id for the environment"
  type        = list(string)
  default     = []
}

variable "cluster_version" {
  description = "Version of the EKS cluster e.g. 1.22"
  type        = string
  default     = "1.23"
}

variable "aws_account_id" {
  description = "The account id for auth roles"
  type        = string
  default     = ""
}

variable "aws_sso_admin_account_role" {
  description = "The AWS SSO Admin Account Role e.g. AWSReservedSSO_AWSAdministratorAccess_{insert hash here}"
  type        = string
  default     = ""
}

variable "domains" {
  description = "The domain of the account"
  type        = list(string)
  default     = ["onedigitaljsr.com"]
}

variable "namespaces" {
  description = "List with namespace definitions to create."
  type = list(object({
    name  = string
    app   = string
    owner = string
    annotations = list(object({
      label  = string
      jvalue = string
    }))
    labels = list(object({
      label = string
      value = string
    }))
  }))
}

variable "extra_kubecost_helm_values" {
  type        = string
  description = "Values in raw yaml to pass to helm to override defaults in the Kubecost Helm Chart."
  default     = ""
}

variable "kubecost_helm_chart_version" {
  default     = "1.44.3"
  type        = string
  description = "The helm chart version of Kubecost. Versions can be found here https://github.com/kubecost/cost-analyzer-helm-chart/releases"
}

variable "kubecost_token" {
  default     = ""
  type        = string
  description = "A user token for Kubecost, obtained from the Kubecost organization. Can be obtained by providing email here https://kubecost.com/install"
}

variable "enable_kubecost" {
  default = false
  type    = bool
}

variable "fargate_profiles" {
  type = any
}

