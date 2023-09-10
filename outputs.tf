output "ping_results_path" {
  value = "${path.cwd}/aggregated_ping_results.txt"
}

output "admin_passwords" {
  value = {
    for i, instance in google_compute_instance.default : 
    instance.name => random_password.password[i].result
  }
  sensitive = true
}

output "vm_external_details" {
  value = {for instance in google_compute_instance.default : instance.name => instance.network_interface[0].access_config[0].nat_ip}
  description = "Map of VM names to their external IP addresses."
}

output "vm_internal_details" {
  value = {for instance in google_compute_instance.default : instance.name => instance.network_interface[0].network_ip}
  description = "Map of VM names to their internal IP addresses."
}
