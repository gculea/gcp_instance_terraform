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
    password  = random_password.password[count.index].result
  }

  metadata_startup_script = <<-EOT
  #!/bin/bash
  TARGET_VM_INDEX=""
  if [ $((${count.index} % ${var.number_of_vms})) -eq 0 ]; then
      TARGET_VM_INDEX=$((${count.index} + 1))
  else
      TARGET_VM_INDEX=$((${count.index} - 1))
  fi

  ping_result=$(ping -c 4 vm-$TARGET_VM_INDEX 2>&1)

  if echo "$ping_result" | grep -q "Temporary failure in name resolution"; then
    echo "Ping from vm-${count.index} to vm-$TARGET_VM_INDEX had a Temporary failure in name resolution" > /tmp/ping_result_vm-${count.index}.txt
  elif echo "$ping_result" | grep -q 'received' && echo "$ping_result" | awk -F',' '{ print $2 }' | awk '{ print $1 }' | grep -q "0"; then
    echo "Ping from vm-${count.index} to vm-$TARGET_VM_INDEX failed" > /tmp/ping_result_vm-${count.index}.txt
  else
    echo "Ping from vm-${count.index} to vm-$TARGET_VM_INDEX succeeded" > /tmp/ping_result_vm-${count.index}.txt
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
      # Wait for 30 seconds to ensure VMs are up
      sleep 30
      for i in $(seq 0 $((${var.number_of_vms} - 1))); do
        gcloud compute scp --zone=us-central1-a "vm-$i:/tmp/ping_result_vm-$i.txt" "/tmp/ping_result_vm-$i.txt"
      done

      # Now aggregate the results
      cat /tmp/ping_result_vm-*.txt > aggregated_ping_results.txt
      '
    EOT
  }
}

