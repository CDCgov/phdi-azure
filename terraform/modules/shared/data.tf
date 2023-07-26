data "azurerm_client_config" "current" {}

#data "azurerm_kubernetes_cluster" "cluster_data" {
#  name = "phdi-${terraform.workspace}-cluster_data"
#  resource_group_name = var.resource_group_name
#
#  depends_on = [
#    azurerm_kubernetes_cluster.cluster
#  ]
#}

data "azurerm_key_vault_secret" "mpi-database-password" {
    name = "mpi_db_password"
    key_vault_id = azurerm_key_vault.phdi_key_vault.id
}