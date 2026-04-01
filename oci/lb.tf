# ──────────────────────────────────────
# Flexible Load Balancer (Free Tier: 10Mbps)
# SSL 종료 + HTTP→HTTPS 리다이렉트
# ──────────────────────────────────────
resource "oci_load_balancer_load_balancer" "main" {
  compartment_id = var.compartment_ocid
  display_name   = "devine-dev-lb"
  shape          = "flexible"
  subnet_ids     = [oci_core_subnet.public.id]

  shape_details {
    minimum_bandwidth_in_mbps = 10
    maximum_bandwidth_in_mbps = 10
  }

  is_private = false

  freeform_tags = {
    "project" = "devine"
    "env"     = "dev"
  }
}

# ──────────────────────────────────────
# LB 인증서 (Let's Encrypt)
# ──────────────────────────────────────
resource "oci_load_balancer_certificate" "main" {
  load_balancer_id   = oci_load_balancer_load_balancer.main.id
  certificate_name   = "devine-kr-cert"
  public_certificate = file(var.ssl_certificate_path)
  private_key        = file(var.ssl_private_key_path)

  lifecycle {
    create_before_destroy = true
  }
}

# ──────────────────────────────────────
# Backend Set → svc:80 (LB가 SSL 종료 후 HTTP로 전달)
# ──────────────────────────────────────
resource "oci_load_balancer_backend_set" "svc" {
  load_balancer_id = oci_load_balancer_load_balancer.main.id
  name             = "svc-backend"
  policy           = "ROUND_ROBIN"

  health_checker {
    protocol          = "HTTP"
    port              = 80
    url_path          = "/actuator/health"
    return_code       = 200
    interval_ms       = 10000
    timeout_in_millis = 3000
    retries           = 3
  }
}

resource "oci_load_balancer_backend" "svc" {
  load_balancer_id = oci_load_balancer_load_balancer.main.id
  backendset_name  = oci_load_balancer_backend_set.svc.name
  ip_address       = oci_core_instance.svc.private_ip
  port             = 80
}

# ──────────────────────────────────────
# Listener - HTTP (80 → 443 리다이렉트)
# ──────────────────────────────────────
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
    }
    response_code = 301
  }
}

resource "oci_load_balancer_listener" "http" {
  load_balancer_id         = oci_load_balancer_load_balancer.main.id
  name                     = "http-listener"
  default_backend_set_name = oci_load_balancer_backend_set.svc.name
  port                     = 80
  protocol                 = "HTTP"

  rule_set_names = [oci_load_balancer_rule_set.https_redirect.name]
}

# ──────────────────────────────────────
# Listener - HTTPS (443, LB에서 SSL 종료)
# ──────────────────────────────────────
resource "oci_load_balancer_listener" "https" {
  load_balancer_id         = oci_load_balancer_load_balancer.main.id
  name                     = "https-listener"
  default_backend_set_name = oci_load_balancer_backend_set.svc.name
  port                     = 443
  protocol                 = "HTTP"

  ssl_configuration {
    certificate_name        = oci_load_balancer_certificate.main.certificate_name
    verify_peer_certificate = false
  }
}
