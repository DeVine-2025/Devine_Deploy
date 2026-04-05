# ──────────────────────────────────────
# VCN
# ──────────────────────────────────────
resource "oci_core_vcn" "main" {
  compartment_id = var.compartment_ocid
  cidr_blocks    = [var.vcn_cidr]
  display_name   = "devine-dev-vcn"
  dns_label      = "devinedev"
}

# ──────────────────────────────────────
# Internet Gateway + Route Table
# ──────────────────────────────────────
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
    network_entity_id = oci_core_internet_gateway.main.id
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
  }
}

# ──────────────────────────────────────
# Security List - 서비스용
# ──────────────────────────────────────
resource "oci_core_security_list" "svc" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.main.id
  display_name   = "devine-dev-svc-sl"

  # Egress: 모든 트래픽 허용
  egress_security_rules {
    protocol    = "all"
    destination = "0.0.0.0/0"
  }

  # SSH
  dynamic "ingress_security_rules" {
    for_each = var.ssh_allow_cidrs
    content {
      protocol = "6" # TCP
      source   = ingress_security_rules.value
      tcp_options {
        min = 22
        max = 22
      }
    }
  }

  # HTTP
  ingress_security_rules {
    protocol = "6"
    source   = "0.0.0.0/0"
    tcp_options {
      min = 80
      max = 80
    }
  }

  # HTTPS
  ingress_security_rules {
    protocol = "6"
    source   = "0.0.0.0/0"
    tcp_options {
      min = 443
      max = 443
    }
  }

  # ICMP (ping)
  ingress_security_rules {
    protocol = "1" # ICMP
    source   = "0.0.0.0/0"
    icmp_options {
      type = 3
      code = 4
    }
  }
}

# ──────────────────────────────────────
# Security List - DB용 (Private Subnet)
# ──────────────────────────────────────
resource "oci_core_security_list" "db" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.main.id
  display_name   = "devine-dev-db-sl"

  egress_security_rules {
    protocol    = "all"
    destination = "0.0.0.0/0"
  }

  # SSH (관리용)
  dynamic "ingress_security_rules" {
    for_each = var.ssh_allow_cidrs
    content {
      protocol = "6"
      source   = ingress_security_rules.value
      tcp_options {
        min = 22
        max = 22
      }
    }
  }

  # PostgreSQL - 같은 Subnet 내에서만 (NSG에서 svc IP로 추가 제한)
  ingress_security_rules {
    protocol = "6"
    source   = var.public_subnet_cidr
    tcp_options {
      min = 5432
      max = 5432
    }
  }

  # Valkey(Redis) - 같은 Subnet 내에서만 (NSG에서 svc IP로 추가 제한)
  ingress_security_rules {
    protocol = "6"
    source   = var.public_subnet_cidr
    tcp_options {
      min = 6379
      max = 6379
    }
  }

  # ICMP
  ingress_security_rules {
    protocol = "1"
    source   = var.vcn_cidr
    icmp_options {
      type = 3
      code = 4
    }
  }
}

# ──────────────────────────────────────
# Subnet - Public (svc, LB)
# ──────────────────────────────────────
resource "oci_core_subnet" "public" {
  compartment_id    = var.compartment_ocid
  vcn_id            = oci_core_vcn.main.id
  cidr_block        = var.public_subnet_cidr
  display_name      = "devine-dev-public-subnet"
  dns_label         = "pub"
  route_table_id    = oci_core_route_table.public.id
  security_list_ids = [oci_core_security_list.svc.id]
}



