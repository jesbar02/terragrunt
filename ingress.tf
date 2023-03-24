data "aws_acm_certificate" "acm_certificate_issued" {
  domain   = var.acm_certificate_domain
  statuses = ["ISSUED"]
}

resource "kubernetes_ingress_v1" "batch-visibility" {
  wait_for_load_balancer = false
  metadata {
    name = "batch-visibility-ingress"
    annotations = {
      "alb.ingress.kubernetes.io/scheme"               = "internal"
      "alb.ingress.kubernetes.io/ssl-policy"           = "ELBSecurityPolicy-TLS-1-2-Ext-2018-06"
      "alb.ingress.kubernetes.io/listen-ports"         = jsonencode([{ "HTTP" : 80 }, { "HTTPS" : 443 }])
      "alb.ingress.kubernetes.io/actions.ssl-redirect" = jsonencode({ "Type" : "redirect", "RedirectConfig" : { "Protocol" : "HTTPS", "Port" : "443", "StatusCode" : "HTTP_301" } })
      "external-dns.alpha.kubernetes.io/hostname"      = var.dns_domain
      "alb.ingress.kubernetes.io/certificate-arn"      = data.aws_acm_certificate.acm_certificate_issued.arn
      "alb.ingress.kubernetes.io/healthcheck-path"     = "/index.html"
      "kubernetes.io/ingress.class"                    = "alb"
      "kubernetes.io/tls-acme"                         = "true"
    }
    namespace = var.namespace
  }

  spec {
    rule {
      host = var.dns_domain
      http {
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = "ssl-redirect"
              port {
                name = "use-annotation"
              }
            }
          }
        }
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = "batch-visibility-web"
              port {
                name = "http"
              }
            }
          }
        }
      }
    }
  }
}