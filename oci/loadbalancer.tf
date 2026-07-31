# ──────────────────────────────────────
# Load Balancer (flexible 10Mbps) + HTTPS
# ──────────────────────────────────────

resource "oci_load_balancer_load_balancer" "main" {
  compartment_id = var.compartment_ocid
  display_name   = "devine-dev-lb"
  shape          = "flexible"
  is_private     = false
  ip_mode        = "IPV4"
  subnet_ids     = [oci_core_subnet.public.id]

  shape_details {
    minimum_bandwidth_in_mbps = 10
    maximum_bandwidth_in_mbps = 10
  }
}

resource "oci_load_balancer_backend_set" "svc" {
  load_balancer_id = oci_load_balancer_load_balancer.main.id
  name             = "svc-backend"
  policy           = "ROUND_ROBIN"

  health_checker {
    protocol            = "HTTP"
    port                = 80
    url_path            = "/actuator/health"
    return_code         = 200
    response_body_regex = ".*"
    interval_ms         = 10000
    timeout_in_millis   = 3000
    retries             = 3
  }
}

resource "oci_load_balancer_backend" "svc" {
  load_balancer_id = oci_load_balancer_load_balancer.main.id
  backendset_name  = oci_load_balancer_backend_set.svc.name
  ip_address       = "10.1.1.125"
  port             = 80
  weight           = 1
  backup           = false
  drain            = false
  offline          = false
}

resource "oci_load_balancer_certificate" "main" {
  load_balancer_id   = oci_load_balancer_load_balancer.main.id
  certificate_name   = "devine-kr-cert"
  public_certificate = try(file(var.ssl_certificate_path), "")
  private_key        = try(file(var.ssl_private_key_path), "")

  lifecycle {
    create_before_destroy = true
    # 인증서 갱신(certbot)은 별도 파이프라인에서 이름을 회전시키며 업로드.
    # 내용 변경으로 인한 재생성/드리프트 방지.
    ignore_changes = [public_certificate, private_key]
  }
}

# HTTP(80) → HTTPS 리다이렉트
resource "oci_load_balancer_listener" "http" {
  load_balancer_id         = oci_load_balancer_load_balancer.main.id
  name                     = "http-listener"
  default_backend_set_name = oci_load_balancer_backend_set.svc.name
  port                     = 80
  protocol                 = "HTTP"
  rule_set_names           = [oci_load_balancer_rule_set.https_redirect.name]

  connection_configuration {
    idle_timeout_in_seconds = "60"
  }
}

# HTTPS(443)
resource "oci_load_balancer_listener" "https" {
  load_balancer_id         = oci_load_balancer_load_balancer.main.id
  name                     = "https-listener"
  default_backend_set_name = oci_load_balancer_backend_set.svc.name
  port                     = 443
  protocol                 = "HTTP"

  ssl_configuration {
    certificate_name        = oci_load_balancer_certificate.main.certificate_name
    cipher_suite_name       = "oci-modern-ssl-cipher-suite-v1"
    protocols               = ["TLSv1.2"]
    server_order_preference = "ENABLED"
    verify_depth            = 1
    verify_peer_certificate = false
  }

  connection_configuration {
    idle_timeout_in_seconds = "180"
  }

  lifecycle {
    # certbot 갱신 시 인증서 이름이 회전되므로 드리프트 무시.
    ignore_changes = [ssl_configuration[0].certificate_name]
  }
}

resource "oci_load_balancer_rule_set" "https_redirect" {
  load_balancer_id = oci_load_balancer_load_balancer.main.id
  name             = "https_redirect"

  items {
    action = "REDIRECT"

    conditions {
      attribute_name  = "PATH"
      attribute_value = "/"
      operator        = "FORCE_LONGEST_PREFIX_MATCH"
    }

    redirect_uri {
      protocol = "HTTPS"
      port     = 443
      query    = "{query}"
    }

    response_code = 301
  }
}
