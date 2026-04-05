output "svc_public_ip" {
  description = "서비스 인스턴스 Public IP"
  value       = oci_core_instance.svc.public_ip
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
  description = "DB 인스턴스 SSH 접속 명령 (svc 경유 Jump Host)"
  value       = "ssh -J ubuntu@${oci_core_instance.svc.public_ip} ubuntu@${oci_core_instance.db.private_ip}"
}

output "lb_public_ip" {
  description = "Load Balancer Public IP"
  value       = oci_load_balancer_load_balancer.main.ip_address_details[0].ip_address
}
