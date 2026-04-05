# ──────────────────────────────────────
# Developer Group
# ──────────────────────────────────────
resource "oci_identity_group" "developers" {
  compartment_id = var.tenancy_ocid
  name           = "devine-developers"
  description    = "DeVine 프로젝트 서버 개발자 그룹"
}

# ──────────────────────────────────────
# Developer User (공용 계정)
# ──────────────────────────────────────
resource "oci_identity_user" "developer" {
  compartment_id = var.tenancy_ocid
  name           = "devine-developer"
  description    = "DeVine 서버 개발자 공용 계정"
  email          = var.developer_email
}

resource "oci_identity_user_group_membership" "developer" {
  group_id = oci_identity_group.developers.id
  user_id  = oci_identity_user.developer.id
}

# 콘솔 로그인용 초기 비밀번호 (apply 후 output에서 확인, 첫 로그인 시 변경 필요)
resource "oci_identity_ui_password" "developer" {
  user_id = oci_identity_user.developer.id
}

# ──────────────────────────────────────
# Policy - 개발자 권한
# ──────────────────────────────────────
resource "oci_identity_policy" "developers" {
  compartment_id = var.tenancy_ocid
  name           = "devine-developer-policy"
  description    = "DeVine 개발자: 리소스 조회/운영 허용, IAM·네트워크 인프라·삭제 제한"

  statements = [
    # 전체 리소스 조회
    "Allow group devine-developers to read all-resources in tenancy",

    # 컴퓨트: 인스턴스 시작/중지/재시작, 콘솔 연결
    "Allow group devine-developers to manage instance-family in tenancy where any {request.permission != 'INSTANCE_DELETE', request.permission != 'INSTANCE_CREATE'}",
    "Allow group devine-developers to manage compute-management-family in tenancy",

    # 로드밸런서: 설정 변경 가능, 삭제 불가
    "Allow group devine-developers to manage load-balancers in tenancy where request.permission != 'LOAD_BALANCER_DELETE'",

    # 네트워크: 사용만 (Security List 수정 가능, VCN/Subnet 생성·삭제 불가)
    "Allow group devine-developers to use virtual-network-family in tenancy",
    "Allow group devine-developers to manage security-lists in tenancy",
    "Allow group devine-developers to manage network-security-groups in tenancy",

    # 볼륨: 조회 + 백업 가능, 삭제 불가
    "Allow group devine-developers to use volumes in tenancy",
    "Allow group devine-developers to manage volume-backups in tenancy",

    # 모니터링/로그
    "Allow group devine-developers to use metrics in tenancy",
    "Allow group devine-developers to use log-content in tenancy",
  ]
}
