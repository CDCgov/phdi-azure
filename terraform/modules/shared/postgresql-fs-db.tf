resource "azurerm_postgresql_flexible_server_database" "mpi" {
  name      = "phdi-${terraform.workspace}-dibbs-mpi-db"
  server_id = azurerm_postgresql_flexible_server.mpi.id
  collation = "en_US.utf8"
  charset   = "utf8"
}