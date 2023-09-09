resource "google_compute_instance" "default" {
  count        = var.number_of_vms
  name         = "vm-${count.index}"
  machine_type = var.vm_flavor
  zone         = "us-central1-a" 

  boot_disk {
    initialize_params {
      image = var.vm_image
    }
  }

  network_interface {
    network = google_compute_network.default.self_link

    access_config {
      // If you want to assign a static external IP, you'd use the "nat_ip" argument here
      nat_ip = google_compute_address.static[count.index].address
    }
  }

  metadata = {
    "ssh-keys" = "gculea:${file("~/.ssh/id_rsa.pub")}"
    password  = random_password.password[count.index].result
  }

  metadata_startup_script = <<-EOT
  #!/bin/bash
  ping_result=$(ping -c 4 vm-$(((${count.index}+1))) | grep 'received' | awk -F',' '{ print $2 }' | awk '{ print $1 }')
  if [ $ping_result -eq 0 ]; then
    echo "Ping from vm-${count.index} to vm-$(((${count.index}+1))) failed" > /tmp/ping_result_vm-${count.index}.txt
  else
    echo "Ping from vm-${count.index} to vm-$(((${count.index}+1))) passed" > /tmp/ping_result_vm-${count.index}.txt
  fi
  EOT
}

resource "null_resource" "aggregate_ping_results" {
  triggers = {
    // Ensuring this runs after all instances have been created
    instances = length(google_compute_instance.default)
  }

  provisioner "local-exec" {
    command = <<-EOT
      bash -c '
      # Loop through each VM and download the file
      # Wait for 60 seconds to ensure VMs are up
      sleep 60
      for i in $(seq 0 $((${var.number_of_vms} - 1))); do
        gcloud compute scp --zone=us-central1-a "vm-$i:/tmp/ping_result_vm-$i.txt" "/tmp/ping_result_vm-$i.txt"
      done

      # Now aggregate the results
      cat /tmp/ping_result_vm-*.txt > aggregated_ping_results.txt
      '
    EOT
  }
}

