# ──────────────────────────────────────
# IAM: 개발자 그룹 / 공용 계정 / 정책
# ──────────────────────────────────────

resource "oci_identity_group" "developers" {
  compartment_id = var.tenancy_ocid
  name           = "devine-developers"
  description    = "DeVine 프로젝트 서버 개발자 그룹"
}

resource "oci_identity_user" "developer" {
  compartment_id = var.tenancy_ocid
  name           = "devine-developer"
  description    = "DeVine 서버 개발자 공용 계정"
  email          = "qetyop9762@gmail.com"
}

resource "oci_identity_user_group_membership" "developer" {
  user_id  = oci_identity_user.developer.id
  group_id = oci_identity_group.developers.id
}

resource "oci_identity_ui_password" "developer" {
  user_id = oci_identity_user.developer.id
}

resource "oci_identity_policy" "developers" {
  compartment_id = var.tenancy_ocid
  name           = "devine-developer-policy"
  description    = "DeVine 개발자: 리소스 조회/운영 허용, IAM·네트워크 인프라·삭제 제한"

  statements = [
    "Allow group devine-developers to read all-resources in tenancy",
    "Allow group devine-developers to manage instance-family in tenancy where any {request.permission != 'INSTANCE_DELETE', request.permission != 'INSTANCE_CREATE'}",
    "Allow group devine-developers to manage compute-management-family in tenancy",
    "Allow group devine-developers to manage load-balancers in tenancy where request.permission != 'LOAD_BALANCER_DELETE'",
    "Allow group devine-developers to use virtual-network-family in tenancy",
    "Allow group devine-developers to manage security-lists in tenancy",
    "Allow group devine-developers to manage network-security-groups in tenancy",
    "Allow group devine-developers to use volumes in tenancy",
    "Allow group devine-developers to manage volume-backups in tenancy",
    "Allow group devine-developers to use metrics in tenancy",
    "Allow group devine-developers to use log-content in tenancy",
  ]
}
