# ──────────────────────────────────────
# Compute 인스턴스 (db / svc)
# ──────────────────────────────────────

data "oci_identity_availability_domains" "ads" {
  compartment_id = var.compartment_ocid
}

# A1.Flex(ARM) 호환 Canonical Ubuntu 22.04 aarch64 최신 이미지.
data "oci_core_images" "ubuntu_arm" {
  compartment_id           = var.compartment_ocid
  operating_system         = "Canonical Ubuntu"
  operating_system_version = "22.04"
  shape                    = "VM.Standard.A1.Flex"
  sort_by                  = "TIMECREATED"
  sort_order               = "DESC"
}

# ── DB 인스턴스: PostgreSQL(pgvector) + Valkey ──
resource "oci_core_instance" "db" {
  availability_domain = "DGVa:AP-CHUNCHEON-1-AD-1"
  compartment_id      = var.compartment_ocid
  display_name        = "devine-dev-db"
  shape               = "VM.Standard.A1.Flex"

  shape_config {
    ocpus         = var.instance_ocpus
    memory_in_gbs = var.instance_memory_gbs
  }

  source_details {
    source_type             = "image"
    source_id               = data.oci_core_images.ubuntu_arm.images[0].id
    boot_volume_size_in_gbs = var.boot_volume_size_gb
    boot_volume_vpus_per_gb = "10"
  }

  create_vnic_details {
    subnet_id        = oci_core_subnet.public.id
    display_name     = "devine-dev-db-vnic"
    hostname_label   = "devine-dev-db-vnic"
    assign_public_ip = true
    private_ip       = "10.1.1.47"
    nsg_ids          = [oci_core_network_security_group.db.id]
    freeform_tags = {
      env     = "dev"
      project = "devine"
      role    = "database"
    }
  }

  metadata = {
    ssh_authorized_keys = var.ssh_public_key
    user_data           = base64encode(file("${path.module}/cloud-init/db.sh"))
  }

  lifecycle {
    ignore_changes = [
      defined_tags,
      create_vnic_details[0].defined_tags,
    ]
  }
}

# ── 서비스 인스턴스: Nginx + API + Realtime + AI ──
resource "oci_core_instance" "svc" {
  availability_domain = "DGVa:AP-CHUNCHEON-1-AD-1"
  compartment_id      = var.compartment_ocid
  display_name        = "devine-dev-svc"
  shape               = "VM.Standard.A1.Flex"

  shape_config {
    ocpus         = var.instance_ocpus
    memory_in_gbs = var.instance_memory_gbs
  }

  source_details {
    source_type             = "image"
    source_id               = data.oci_core_images.ubuntu_arm.images[0].id
    boot_volume_size_in_gbs = var.boot_volume_size_gb
    boot_volume_vpus_per_gb = "10"
  }

  create_vnic_details {
    subnet_id        = oci_core_subnet.public.id
    display_name     = "devine-dev-svc-vnic"
    hostname_label   = "devine-dev-svc-vnic"
    assign_public_ip = true
    private_ip       = "10.1.1.125"
    freeform_tags = {
      env     = "dev"
      project = "devine"
      role    = "service"
    }
  }

  metadata = {
    ssh_authorized_keys = var.ssh_public_key
    user_data           = base64encode(file("${path.module}/cloud-init/svc.sh"))
  }

  lifecycle {
    ignore_changes = [
      defined_tags,
      create_vnic_details[0].defined_tags,
    ]
  }
}
