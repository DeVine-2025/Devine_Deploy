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

# 현재 배포된 인스턴스 이미지(Canonical Ubuntu 22.04 x86).
# A1.Flex 전환 시 aarch64 이미지 OCID로 교체.
variable "instance_image_ocid" {
  type    = string
  default = "ocid1.image.oc1.ap-chuncheon-1.aaaaaaaapowkteh6y63zv77rbifj225qz2oyvuki74zgw2l33twoglgo3x6q"
}

# ── 네트워크 접근 제어 ──
variable "ssh_allow_cidrs" {
  type    = list(string)
  default = ["0.0.0.0/0"]
}

# ── SSL 인증서 (Let's Encrypt) ──
variable "ssl_certificate_path" { type = string }
variable "ssl_private_key_path" { type = string }
