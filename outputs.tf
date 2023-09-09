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