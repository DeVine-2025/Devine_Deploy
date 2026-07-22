# ──────────────────────────────────────
# DB 데이터용 Block Volume
# 부트볼륨과 분리 → 인스턴스 재생성(A1 전환 등)에도 데이터 보존.
# 마운트/포맷 및 postgres 데이터 경로 연결은 부트스트랩 단계에서 수행.
# ──────────────────────────────────────

resource "oci_core_volume" "db_data" {
  compartment_id      = var.compartment_ocid
  availability_domain = "DGVa:AP-CHUNCHEON-1-AD-1"
  display_name        = "devine-dev-db-data"
  size_in_gbs         = var.db_data_volume_size_gb

  freeform_tags = {
    env     = "dev"
    project = "devine"
    role    = "database"
  }
}

resource "oci_core_volume_attachment" "db_data" {
  attachment_type = "paravirtualized"
  instance_id     = oci_core_instance.db.id
  volume_id       = oci_core_volume.db_data.id
  display_name    = "devine-dev-db-data-attach"
}
