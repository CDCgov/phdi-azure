data "azurerm_client_config" "current" {}

data "azurerm_kubernetes_cluster" "cluster_data" {
  name = "phdi-${terraform.workspace}-cluster_data"
  resource_group_name = var.resource_group_name

  depends_on = [
    azurerm_kubernetes_cluster.cluster
  ]
}