# ──────────────────────────────────────
# OCI Provider 인증
# ──────────────────────────────────────
variable "tenancy_ocid" {
  description = "OCI Tenancy OCID"
  type        = string
}

variable "user_ocid" {
  description = "OCI User OCID"
  type        = string
}

variable "fingerprint" {
  description = "API Key fingerprint"
  type        = string
}

variable "private_key_path" {
  description = "API Key private key 경로"
  type        = string
  default     = "~/.oci/oci_api_key.pem"
}

variable "region" {
  description = "OCI 리전"
  type        = string
  default     = "ap-chuncheon-1" # 춘천 (서울 리전: ap-seoul-1)
}

variable "compartment_ocid" {
  description = "리소스를 생성할 Compartment OCID (root tenancy 또는 하위 compartment)"
  type        = string
}

# ──────────────────────────────────────
# 컴퓨트
# ──────────────────────────────────────
variable "ssh_public_key" {
  description = "SSH 공개 키 (인스턴스 접속용)"
  type        = string
}

variable "boot_volume_size_gb" {
  description = "부트 볼륨 크기(GB)"
  type        = number
  default     = 50
}

# ──────────────────────────────────────
# 네트워크
# ──────────────────────────────────────
variable "vcn_cidr" {
  description = "VCN CIDR 블록"
  type        = string
  default     = "10.1.0.0/16"
}

variable "public_subnet_cidr" {
  description = "Public Subnet CIDR"
  type        = string
  default     = "10.1.1.0/24"
}

variable "private_subnet_cidr" {
  description = "Private Subnet CIDR (DB)"
  type        = string
  default     = "10.1.2.0/24"
}

variable "ssh_allow_cidrs" {
  description = "SSH 접속 허용 CIDR 목록"
  type        = list(string)
  default     = ["0.0.0.0/0"] # 팀 공유 목적
}

# ──────────────────────────────────────
# SSL 인증서
# ──────────────────────────────────────
variable "ssl_certificate_path" {
  description = "Let's Encrypt fullchain.pem 경로"
  type        = string
}

variable "ssl_private_key_path" {
  description = "Let's Encrypt privkey.pem 경로"
  type        = string
}
