# ── OCI Provider 인증 ──
variable "tenancy_ocid" { type = string }
variable "user_ocid" { type = string }
variable "fingerprint" { type = string }
variable "private_key_path" { type = string }
variable "region" {
  type    = string
  default = "ap-chuncheon-1"
}
variable "compartment_ocid" { type = string }

# ── SSH ──
variable "ssh_public_key" { type = string }

# ── 인스턴스 스펙 ──
variable "boot_volume_size_gb" {
  type    = number
  default = 50
}

# A1.Flex(ARM) shape 설정. 상시무료 총량은 4 OCPU / 24GB.
# db·svc 각 1 OCPU/6GB → 합 2 OCPU/12GB (한도 내).
variable "instance_ocpus" {
  type    = number
  default = 1
}
variable "instance_memory_gbs" {
  type    = number
  default = 6
}

# DB 데이터용 Block Volume 크기 (부트볼륨과 분리하여 재생성에도 데이터 보존).
variable "db_data_volume_size_gb" {
  type    = number
  default = 50
}

# ── 네트워크 접근 제어 ──
variable "ssh_allow_cidrs" {
  type    = list(string)
  default = ["0.0.0.0/0"]
}

# ── SSL 인증서 (Let's Encrypt) ──
variable "ssl_certificate_path" { type = string }
variable "ssl_private_key_path" { type = string }
