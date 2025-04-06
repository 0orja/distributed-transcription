resource "local_file" "ansible_hosts" {
  filename = "${path.module}/../ansible-slurm/hosts"
  content = templatefile("${path.module}/hosts.tmpl", {
    host_ip  = harvester_virtualmachine.host[0].network_interface[0].ip_address
    worker_ips  = [for vm in harvester_virtualmachine.workervm : vm.network_interface[0].ip_address]
  })
}

resource "local_file" "ansible_vars" {
  filename = "${path.module}/../ansible-slurm/vars.yaml"
  content = templatefile("${path.module}/ansible_vars.tmpl.yaml", {
    host_ip = harvester_virtualmachine.host[0].network_interface[0].ip_address
    worker_ips = [for vm in harvester_virtualmachine.workervm : vm.network_interface[0].ip_address]
    prometheus_port = local.monitoring_host_tags.condenser_ingress_prometheus_port
    grafana_hostname = local.monitoring_host_tags.condenser_ingress_grafana_hostname
    nodeexporter_port = local.monitoring_host_tags.condenser_ingress_nodeexporter_port
    minio_s3_port = local.minio_tags.condenser_ingress_os_port
    minio_s3_hostname = local.minio_tags.condenser_ingress_os_hostname
    minio_console_port = local.minio_tags.condenser_ingress_cons_port
  })
}