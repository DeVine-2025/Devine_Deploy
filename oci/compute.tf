# ──────────────────────────────────────
# Ubuntu 22.04 x86 이미지 조회 (VM.Standard.E2.1.Micro)
# ──────────────────────────────────────
data "oci_core_images" "ubuntu_x86" {
  compartment_id           = var.compartment_ocid
  operating_system         = "Canonical Ubuntu"
  operating_system_version = "22.04"
  shape                    = "VM.Standard.E2.1.Micro"
  sort_by                  = "TIMECREATED"
  sort_order               = "DESC"
}

# ──────────────────────────────────────
# Availability Domain 조회
# ──────────────────────────────────────
data "oci_identity_availability_domains" "ads" {
  compartment_id = var.tenancy_ocid
}

# ──────────────────────────────────────
# 서비스 인스턴스 (Nginx + API + Realtime + AI)
# ──────────────────────────────────────
resource "oci_core_instance" "svc" {
  compartment_id      = var.compartment_ocid
  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[0].name
  display_name        = "devine-dev-svc"
  shape               = "VM.Standard.E2.1.Micro"

  source_details {
    source_type             = "image"
    source_id               = data.oci_core_images.ubuntu_x86.images[0].id
    boot_volume_size_in_gbs = var.boot_volume_size_gb
  }

  create_vnic_details {
    subnet_id        = oci_core_subnet.public.id
    display_name     = "devine-dev-svc-vnic"
    assign_public_ip = true
    nsg_ids          = []
  }

  metadata = {
    ssh_authorized_keys = var.ssh_public_key
    user_data           = base64encode(file("${path.module}/scripts/setup-svc.sh"))
  }

  freeform_tags = {
    "project" = "devine"
    "env"     = "dev"
    "role"    = "service"
  }

  lifecycle {
    ignore_changes = [metadata, source_details, defined_tags, fault_domain]
  }
}

# ──────────────────────────────────────
# DB 인스턴스 (PostgreSQL + Valkey)
# ──────────────────────────────────────
resource "oci_core_instance" "db" {
  compartment_id      = var.compartment_ocid
  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[0].name
  display_name        = "devine-dev-db"
  shape               = "VM.Standard.E2.1.Micro"

  source_details {
    source_type             = "image"
    source_id               = data.oci_core_images.ubuntu_x86.images[0].id
    boot_volume_size_in_gbs = var.boot_volume_size_gb
  }

  create_vnic_details {
    subnet_id        = oci_core_subnet.public.id
    display_name     = "devine-dev-db-vnic"
    assign_public_ip = true # SSH 관리용, DB 포트는 NSG에서 svc IP로 제한
    nsg_ids          = [oci_core_network_security_group.db.id]
  }

  metadata = {
    ssh_authorized_keys = var.ssh_public_key
    user_data           = base64encode(file("${path.module}/scripts/setup-db.sh"))
  }

  freeform_tags = {
    "project" = "devine"
    "env"     = "dev"
    "role"    = "database"
  }

  lifecycle {
    ignore_changes = [metadata, source_details, defined_tags, fault_domain]
  }
}

# ──────────────────────────────────────
# NSG - DB 인스턴스용 (Subnet Security List 위에 추가 제한)
# ──────────────────────────────────────
resource "oci_core_network_security_group" "db" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.main.id
  display_name   = "devine-dev-db-nsg"
}

# PostgreSQL: svc 인스턴스 Private IP에서만 허용
resource "oci_core_network_security_group_security_rule" "db_postgres" {
  network_security_group_id = oci_core_network_security_group.db.id
  direction                 = "INGRESS"
  protocol                  = "6" # TCP
  source                    = "${oci_core_instance.svc.private_ip}/32"
  source_type               = "CIDR_BLOCK"

  tcp_options {
    destination_port_range {
      min = 5432
      max = 5432
    }
  }
}

# Valkey: svc 인스턴스 Private IP에서만 허용
resource "oci_core_network_security_group_security_rule" "db_valkey" {
  network_security_group_id = oci_core_network_security_group.db.id
  direction                 = "INGRESS"
  protocol                  = "6"
  source                    = "${oci_core_instance.svc.private_ip}/32"
  source_type               = "CIDR_BLOCK"

  tcp_options {
    destination_port_range {
      min = 6379
      max = 6379
    }
  }
}
