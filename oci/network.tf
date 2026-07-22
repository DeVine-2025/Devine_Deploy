# ──────────────────────────────────────
# VCN / 서브넷 / 게이트웨이 / 라우팅
# ──────────────────────────────────────

resource "oci_core_vcn" "main" {
  compartment_id = var.compartment_ocid
  cidr_blocks    = ["10.1.0.0/16"]
  display_name   = "devine-dev-vcn"
  dns_label      = "devinedev"
}

resource "oci_core_internet_gateway" "main" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.main.id
  display_name   = "devine-dev-igw"
  enabled        = true
}

resource "oci_core_route_table" "public" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.main.id
  display_name   = "devine-dev-public-rt"

  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_internet_gateway.main.id
  }
}

resource "oci_core_subnet" "public" {
  compartment_id             = var.compartment_ocid
  vcn_id                     = oci_core_vcn.main.id
  cidr_block                 = "10.1.1.0/24"
  display_name               = "devine-dev-public-subnet"
  dns_label                  = "pub"
  route_table_id             = oci_core_route_table.public.id
  security_list_ids          = [oci_core_security_list.svc.id]
  prohibit_public_ip_on_vnic = false
}

# ── 서비스 인스턴스용 Security List (SSH/HTTP/HTTPS/ICMP) ──
resource "oci_core_security_list" "svc" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.main.id
  display_name   = "devine-dev-svc-sl"

  egress_security_rules {
    destination      = "0.0.0.0/0"
    destination_type = "CIDR_BLOCK"
    protocol         = "all"
  }

  # ICMP (path MTU / fragmentation needed)
  ingress_security_rules {
    protocol    = "1"
    source      = "0.0.0.0/0"
    source_type = "CIDR_BLOCK"
    icmp_options {
      type = 3
      code = 4
    }
  }

  ingress_security_rules {
    protocol    = "6"
    source      = "0.0.0.0/0"
    source_type = "CIDR_BLOCK"
    tcp_options {
      min = 22
      max = 22
    }
  }

  ingress_security_rules {
    protocol    = "6"
    source      = "0.0.0.0/0"
    source_type = "CIDR_BLOCK"
    tcp_options {
      min = 443
      max = 443
    }
  }

  ingress_security_rules {
    protocol    = "6"
    source      = "0.0.0.0/0"
    source_type = "CIDR_BLOCK"
    tcp_options {
      min = 80
      max = 80
    }
  }
}

# ── DB 인스턴스용 NSG (svc에서만 postgres/valkey 접근 허용) ──
resource "oci_core_network_security_group" "db" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.main.id
  display_name   = "devine-dev-db-nsg"
}

resource "oci_core_network_security_group_security_rule" "db_postgres" {
  network_security_group_id = oci_core_network_security_group.db.id
  direction                 = "INGRESS"
  protocol                  = "6"
  source                    = "10.1.1.125/32"
  source_type               = "CIDR_BLOCK"
  stateless                 = false

  tcp_options {
    destination_port_range {
      min = 5432
      max = 5432
    }
  }
}

resource "oci_core_network_security_group_security_rule" "db_valkey" {
  network_security_group_id = oci_core_network_security_group.db.id
  direction                 = "INGRESS"
  protocol                  = "6"
  source                    = "10.1.1.125/32"
  source_type               = "CIDR_BLOCK"
  stateless                 = false

  tcp_options {
    destination_port_range {
      min = 6379
      max = 6379
    }
  }
}
