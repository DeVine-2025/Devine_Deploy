output "svc_public_ip" {
  description = "서비스 인스턴스 Public IP"
  value       = oci_core_instance.svc.public_ip
}

output "db_public_ip" {
  description = "DB 인스턴스 Public IP (SSH 관리용)"
  value       = oci_core_instance.db.public_ip
}

output "db_private_ip" {
  description = "DB 인스턴스 Private IP (서비스→DB 연결용)"
  value       = oci_core_instance.db.private_ip
}

output "ssh_svc" {
  description = "서비스 인스턴스 SSH 접속 명령"
  value       = "ssh ubuntu@${oci_core_instance.svc.public_ip}"
}

output "ssh_db" {
  description = "DB 인스턴스 SSH 접속 명령"
  value       = "ssh ubuntu@${oci_core_instance.db.public_ip}"
}

output "developer_console_password" {
  description = "개발자 계정 초기 비밀번호 (첫 로그인 시 변경 필요)"
  value       = oci_identity_ui_password.developer.password
  sensitive   = true
}

output "lb_public_ip" {
  description = "Load Balancer Public IP"
  value       = oci_load_balancer_load_balancer.main.ip_address_details[0].ip_address
}
