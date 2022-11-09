resource "helm_release" "metric-server" {
    count = var.addon_selected.metric_server ? 1 : 0
    name      = "metric-server"
    namespace = "kube-system"

    repository = "https://kubernetes-sigs.github.io/metrics-server/"
    chart      = "metrics-server"
    version    = "3.8.2"

    values     = [
        "${file("helm_values/metric.yaml")}"
    ]

    set {
        name  = "image.repository"
        value = "v2-zcr.cloudzcp.io/cloudzcp-public/metrics-server/metrics-server"
    }

    set {
        name  = "image.tag"
        value = "v0.6.1"
    }

    set {
        name  = "apiService.create"
        value = true
    }
}


resource "null_resource" "metric-server_start" {

  provisioner "local-exec" {
  command = "echo ADD-ON -  Metric-server Installation : Start >> logs/process.log"
  }
}


resource "null_resource" "metric-server_completed" {

  depends_on = [helm_release.metric-server]

  provisioner "local-exec" {
  command = "echo ADD-ON - Metric-server Installation : Completed  >> logs/process.log"
  }
}