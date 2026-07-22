output "svc_public_ip" {
  value = oci_core_instance.svc.public_ip
}

output "db_public_ip" {
  value = oci_core_instance.db.public_ip
}

output "db_private_ip" {
  value = oci_core_instance.db.private_ip
}

output "lb_public_ip" {
  value = oci_load_balancer_load_balancer.main.ip_address_details[0].ip_address
}

output "ssh_svc" {
  value = "ssh ubuntu@${oci_core_instance.svc.public_ip}"
}

output "ssh_db" {
  value = "ssh ubuntu@${oci_core_instance.db.public_ip}"
}

output "developer_console_password" {
  value     = oci_identity_ui_password.developer.password
  sensitive = true
}
