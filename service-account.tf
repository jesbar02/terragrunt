resource "kubernetes_service_account" "batch-visibility-service-account" {
  metadata {
    name      = "batch-visibility-admin"
    namespace = var.namespace
    annotations = {
      "eks.amazonaws.com/role-arn" = "${tostring(module.iam_eks_role.iam_role_arn)}"
    }
  }
  automount_service_account_token = true
}

resource "kubernetes_role" "batch-visibility-service-account-role" {
  metadata {
    name      = "batch-visibility-admin-role"
    namespace = var.namespace
  }
  rule {
    api_groups = ["*"]
    resources = [
      "jobs",
      "pods",
      "pods/log",
      "pods/exec",
      "pods/attach"
    ]
    verbs = [
      "get",
      "list",
      "watch",
      "create",
      "update",
      "patch",
      "delete"
    ]
  }
}

resource "kubernetes_role_binding" "batch-visibility-api-service-account-binding" {
  metadata {
    name      = "batch-visibility-admin-binding"
    namespace = var.namespace
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = "batch-visibility-admin-role"
  }

  subject {
    kind = "ServiceAccount"
    name = "batch-visibility-admin"
  }
}