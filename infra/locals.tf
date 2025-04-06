locals {
  monitoring_host_tags = {
    condenser_ingress_prometheus_hostname = "prometheus-${var.username}"
    condenser_ingress_prometheus_port = 9090
    condenser_ingress_nodeexporter_hostname = "nodeexporter-${var.username}"
    condenser_ingress_nodeexporter_port = 9100
    condenser_ingress_grafana_hostname = "grafana-${var.username}"
    condenser_ingress_grafana_port = 3000
  }
  monitoring_client_tags = {
    condenser_ingress_isAllowed = true
    condenser_ingress_isEnabled = true
    condenser_ingress_node_hostname = "node-${var.username}"
    condenser_ingress_node_port  = 9100
    }
  minio_tags = {
    condenser_ingress_isEnabled = true
    condenser_ingress_os_hostname = "${var.username}-s3"
    condenser_ingress_os_port = 9200
    condenser_ingress_os_protocol = "https"
    condenser_ingress_os_nginx_proxy-body-size = "100000m"
    condenser_ingress_cons_hostname = "${var.username}-cons"
    condenser_ingress_cons_port = 9201
    condenser_ingress_cons_protocol = "https"
    condenser_ingress_cons_nginx_proxy-body-size = "100000m"
  }
}