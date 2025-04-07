data "harvester_image" "img" {
  display_name = var.img_display_name
  namespace    = "harvester-public"
}

data "harvester_ssh_key" "mysshkey" {
  name      = var.keyname
  namespace = var.namespace
}

resource "harvester_ssh_key" "lecturer_key" {
  name       = "merizo-lecturer-key"
  public_key = file("lecturer_key.pub")
  namespace  = var.namespace
}

resource "tls_private_key" "host_key" {
  algorithm = "ED25519"
}

resource "random_id" "secret" {
  byte_length = 5
}

resource "harvester_cloudinit_secret" "worker-cloud-config" {
  name      = "worker-cloud-config-${random_id.secret.hex}"
  namespace = var.namespace

  user_data = templatefile("cloud-init-worker.tmpl.yml", {
      public_key_openssh = data.harvester_ssh_key.mysshkey.public_key
      lecturer_key_openssh = harvester_ssh_key.lecturer_key.public_key
      host_key_openssh = tls_private_key.host_key.public_key_openssh
    })
}

resource "harvester_cloudinit_secret" "host-cloud-config" {
  name      = "host-cloud-config-${random_id.secret.hex}"
  namespace = var.namespace

  user_data = templatefile("cloud-init-host.tmpl.yml", {
      public_key_openssh = data.harvester_ssh_key.mysshkey.public_key
      lecturer_key_openssh = harvester_ssh_key.lecturer_key.public_key
      host_key_openssh = tls_private_key.host_key.public_key_openssh
      worker_ips = join("\n", [for vm in harvester_virtualmachine.workervm : "${vm.network_interface[0].ip_address}"])
      prometheus_port = local.monitoring_host_tags.condenser_ingress_prometheus_port
      grafana_hostname = local.monitoring_host_tags.condenser_ingress_grafana_hostname
      nodeexporter_port = local.monitoring_host_tags.condenser_ingress_nodeexporter_port
      minio_s3_port = local.minio_tags.condenser_ingress_os_port
      minio_s3_hostname = local.minio_tags.condenser_ingress_os_hostname
      minio_console_port = local.minio_tags.condenser_ingress_cons_port
      minio_console_hostname = local.minio_tags.condenser_ingress_cons_hostname
    })
}

resource "harvester_virtualmachine" "host" {

  lifecycle {
    replace_triggered_by = [
      harvester_cloudinit_secret.host-cloud-config.user_data
    ]
  }
  
  count = 1

  name                 = "${var.username}-benchmark-host"
  namespace            = var.namespace
  restart_after_update = true

  description = "Cluster host Node"

  cpu    = 2 
  memory = "4Gi"

  efi         = true
  secure_boot = false

  run_strategy    = "RerunOnFailure"
  hostname        = "${var.username}-benchmark-host"
  reserved_memory = "100Mi"
  machine_type    = "q35"

  network_interface {
    name           = "nic-1"
    wait_for_lease = true
    type           = "bridge"
    network_name   = var.network_name
  }

  disk {
    name       = "rootdisk"
    type       = "disk"
    size       = "10Gi"
    bus        = "virtio"
    boot_order = 1

    image       = data.harvester_image.img.id
    auto_delete = true
  }

  cloudinit {
    user_data_secret_name = harvester_cloudinit_secret.host-cloud-config.name
  }

  tags = merge(local.monitoring_host_tags, local.minio_tags, local.monitoring_client_tags)

  connection {
    type        = "ssh"
    host        = self.network_interface[0].ip_address
    user        = "almalinux"
    private_key = tls_private_key.host_key.private_key_openssh
  }
  provisioner "remote-exec" {
    inline = [
      "cat > ~/.ssh/ansible_key << 'EOL'",
      "${tls_private_key.host_key.private_key_openssh}",
      "EOL",
      "chmod 600 ~/.ssh/ansible_key",
      "cat > ~/.ssh/ansible_key.pub << 'EOL'",
      "${tls_private_key.host_key.public_key_openssh}",
      "EOL",
      "chmod 644 ~/.ssh/ansible_key.pub",
      "ls -la ~/.ssh/",
    ]
  }
}

resource "harvester_virtualmachine" "workervm" {
  
  count = var.worker_count

  name                 = "${var.username}-benchmark-worker-${format("%02d", count.index + 1)}-${random_id.secret.hex}"
  namespace            = var.namespace
  restart_after_update = true

  description = "Cluster Compute Node"

  cpu    = 4
  memory = "32Gi"

  efi         = true
  secure_boot = false

  run_strategy    = "RerunOnFailure"
  hostname        = "${var.username}-benchmark-worker-${format("%02d", count.index + 1)}-${random_id.secret.hex}"
  reserved_memory = "100Mi"
  machine_type    = "q35"

  network_interface {
    name           = "nic-1"
    wait_for_lease = true
    type           = "bridge"
    network_name   = var.network_name
  }

  disk {
    name       = "rootdisk"
    type       = "disk"
    size       = "50Gi"
    bus        = "virtio"
    boot_order = 1

    image       = data.harvester_image.img.id
    auto_delete = true
  }

  disk {
    name       = "datadisk"
    type       = "disk"
    size       = "200Gi"
    bus        = "virtio"
    boot_order = 2

    auto_delete = true
  }

  cloudinit {
    user_data_secret_name = harvester_cloudinit_secret.worker-cloud-config.name
  }

  tags = local.monitoring_client_tags
}
