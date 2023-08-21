# Locals block for hardcoded names
locals {
  backend_address_pool_name      = "${azurerm_virtual_network.aks_vnet.name}-beap"
  frontend_port_name             = "${azurerm_virtual_network.aks_vnet.name}-feport"
  frontend_ip_configuration_name = "${azurerm_virtual_network.aks_vnet.name}-feip"
  http_setting_name              = "${azurerm_virtual_network.aks_vnet.name}-be-htst"
  listener_name                  = "${azurerm_virtual_network.aks_vnet.name}-httplstn"
  request_routing_rule_name      = "${azurerm_virtual_network.aks_vnet.name}-rqrt"

  aks_vnet_name           = "phdi-${terraform.workspace}-aks-vnet"
  aks_subnet_name         = "phdi-${terraform.workspace}-aks-subnet"
  aks_cluster_name        = "phdi-${terraform.workspace}-aks-cluster"
  aks_dns_prefix          = "phdi-${terraform.workspace}"
  app_gateway_name        = "phdi-${terraform.workspace}-aks-appgw"
  app_gateway_subnet_name = "phdi-${terraform.workspace}-aks-appgw-subnet"

  services = toset([
    "fhir-converter",
    "ingestion",
    "tabulation",
    "alerts",
    "message-parser",
    "validation",
    "record-linkage",
  ])
}

# Service Principal
resource "azuread_application" "aks" {
  display_name = "phdi-${terraform.workspace}-aks"
  owners       = [data.azuread_client_config.current.object_id]
}

resource "azuread_service_principal" "aks" {
  application_id               = azuread_application.aks.application_id
  app_role_assignment_required = false
  owners                       = [data.azuread_client_config.current.object_id]
}

resource "azuread_service_principal_password" "aks" {
  service_principal_id = azuread_service_principal.aks.object_id
}

resource "azurerm_role_assignment" "gateway_contributor" {
  scope                = azurerm_application_gateway.network.id
  role_definition_name = "Contributor"
  principal_id         = azuread_service_principal.aks.object_id
}

resource "azurerm_role_assignment" "resource_group_reader" {
  scope                = data.azurerm_resource_group.rg.id
  role_definition_name = "Reader"
  principal_id         = azuread_service_principal.aks.object_id
}

resource "azurerm_role_assignment" "public_ip_reader" {
  scope                = azurerm_public_ip.aks.id
  role_definition_name = "Reader"
  principal_id         = azuread_service_principal.aks.object_id
}

resource "azurerm_role_assignment" "app_gateway_subnet_network_contributor" {
  scope                = data.azurerm_subnet.appgwsubnet.id
  role_definition_name = "Network Contributor"
  principal_id         = azuread_service_principal.aks.object_id
}

# SSH Key
resource "random_pet" "ssh_key_name" {
  prefix    = "ssh"
  separator = ""
}

resource "azapi_resource_action" "ssh_public_key_gen" {
  type        = "Microsoft.Compute/sshPublicKeys@2022-11-01"
  resource_id = azapi_resource.ssh_public_key.id
  action      = "generateKeyPair"
  method      = "POST"

  response_export_values = ["publicKey", "privateKey"]
}

resource "azapi_resource" "ssh_public_key" {
  type      = "Microsoft.Compute/sshPublicKeys@2022-11-01"
  name      = random_pet.ssh_key_name.id
  location  = var.location
  parent_id = data.azurerm_resource_group.rg.id
}

#### VNET for kubernetes ####

resource "azurerm_virtual_network" "aks_vnet" {
  name                = local.aks_vnet_name
  resource_group_name = var.resource_group_name
  address_space       = [var.k8s_vnet_address_space]
  location            = var.location

  subnet {
    name           = local.aks_subnet_name
    address_prefix = var.k8s_subnet_address_prefix
  }

  subnet {
    name           = local.app_gateway_subnet_name
    address_prefix = var.app_gateway_subnet_address_prefix
  }
}

# Public Ip 
resource "azurerm_public_ip" "aks" {
  name                = "phdi-${terraform.workspace}-aks-pip"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_application_gateway" "network" {
  name                = local.app_gateway_name
  resource_group_name = var.resource_group_name
  location            = var.location

  sku {
    name     = var.app_gateway_sku
    tier     = "Standard_v2"
    capacity = 2
  }

  gateway_ip_configuration {
    name      = "appGatewayIpConfig"
    subnet_id = data.azurerm_subnet.appgwsubnet.id
  }

  frontend_port {
    name = local.frontend_port_name
    port = 80
  }

  frontend_port {
    name = "httpsPort"
    port = 443
  }

  frontend_ip_configuration {
    name                 = local.frontend_ip_configuration_name
    public_ip_address_id = azurerm_public_ip.aks.id
  }

  backend_address_pool {
    name = local.backend_address_pool_name
  }

  backend_http_settings {
    name                  = local.http_setting_name
    cookie_based_affinity = "Disabled"
    port                  = 80
    protocol              = "Http"
    request_timeout       = 1
  }

  http_listener {
    name                           = local.listener_name
    frontend_ip_configuration_name = local.frontend_ip_configuration_name
    frontend_port_name             = local.frontend_port_name
    protocol                       = "Http"
  }

  request_routing_rule {
    name                       = local.request_routing_rule_name
    rule_type                  = "Basic"
    http_listener_name         = local.listener_name
    backend_address_pool_name  = local.backend_address_pool_name
    backend_http_settings_name = local.http_setting_name
    priority                   = 1
  }
}

#### Kubernetes Service ####

resource "azurerm_kubernetes_cluster" "k8s" {
  name                = local.aks_cluster_name
  location            = var.location
  resource_group_name = var.resource_group_name
  dns_prefix          = local.aks_dns_prefix

  default_node_pool {
    name            = "agentpool"
    node_count      = var.aks_agent_count
    vm_size         = var.aks_agent_vm_size
    os_disk_size_gb = var.aks_agent_os_disk_size
    vnet_subnet_id  = data.azurerm_subnet.kubesubnet.id
  }

  identity {
    type = "SystemAssigned"
  }

  network_profile {
    network_plugin     = "azure"
    dns_service_ip     = var.aks_dns_service_ip
    service_cidr       = var.aks_service_cidr
  }

  http_application_routing_enabled = false

  linux_profile {
    admin_username = var.vm_username

    ssh_key {
      key_data = jsondecode(azapi_resource_action.ssh_public_key_gen.output).publicKey
    }
  }

  azure_active_directory_role_based_access_control {
    managed            = true
    azure_rbac_enabled = true
  }
}

# Key vault

resource "azurerm_key_vault" "phdi_key_vault" {
  name                       = "${terraform.workspace}vault${substr(var.client_id, 0, 8)}"
  location                   = var.location
  resource_group_name        = var.resource_group_name
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "premium"
  soft_delete_retention_days = 7


  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azurerm_client_config.current.object_id

    key_permissions = [
      "Create",
      "Get",
    ]

    secret_permissions = [
      "Set",
      "Get",
      "Delete",
      "Purge",
      "Recover"
    ]
  }
}

resource "azurerm_key_vault_secret" "smarty_auth_id" {
  name         = "smarty-auth-id"
  value        = var.smarty_auth_id
  key_vault_id = azurerm_key_vault.phdi_key_vault.id
}

resource "azurerm_key_vault_secret" "smarty_auth_token" {
  name         = "smarty-auth-token"
  value        = var.smarty_auth_token
  key_vault_id = azurerm_key_vault.phdi_key_vault.id
}

# Postgres

resource "random_password" "postgres_password" {
  length           = 32
  special          = true
  override_special = "_%@"
}

resource "azurerm_postgresql_flexible_server" "mpi" {
  name                         = "phdi${terraform.workspace}mpi${substr(var.client_id, 0, 8)}"
  resource_group_name          = var.resource_group_name
  location                     = var.location
  sku_name                     = "GP_Standard_D2s_v3"
  version                      = "14"
  storage_mb                   = 65536
  backup_retention_days        = 7
  geo_redundant_backup_enabled = true
  administrator_login          = "postgres"
  administrator_password       = random_password.postgres_password.result
  tags = {
    environment = terraform.workspace
    managed-by  = "terraform"
  }

  lifecycle {
    ignore_changes = [zone]
  }
}

resource "azurerm_postgresql_flexible_server_configuration" "mpi" {
  name      = "azure.extensions"
  server_id = azurerm_postgresql_flexible_server.mpi.id
  value     = "UUID-OSSP"
}

resource "azurerm_postgresql_flexible_server_database" "mpi" {
  name      = "DibbsMpiDB"
  server_id = azurerm_postgresql_flexible_server.mpi.id
  collation = "en_US.utf8"
  charset   = "utf8"
}

// Allow Azure services to access the database
// See here: https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/postgresql_firewall_rule
resource "azurerm_postgresql_flexible_server_firewall_rule" "allow_azure_services" {
  name             = "allow_azure_services"
  server_id        = azurerm_postgresql_flexible_server.mpi.id
  start_ip_address = "0.0.0.0"
  end_ip_address   = "0.0.0.0"
}

# Helm

provider "helm" {
  kubernetes {
    host                   = azurerm_kubernetes_cluster.k8s.kube_config.0.host
    client_certificate     = base64decode(azurerm_kubernetes_cluster.k8s.kube_config.0.client_certificate)
    client_key             = base64decode(azurerm_kubernetes_cluster.k8s.kube_config.0.client_key)
    cluster_ca_certificate = base64decode(azurerm_kubernetes_cluster.k8s.kube_config.0.cluster_ca_certificate)
  }
}

# Application Gateway Ingress Controller

resource "helm_release" "agic" {
  name       = "aks-agic"
  repository = "https://appgwingress.blob.core.windows.net/ingress-azure-helm-package"
  chart      = "ingress-azure"
  depends_on = [azurerm_kubernetes_cluster.k8s]

  values = [
    "${templatefile("helm-agic-config.yaml", {
      subscription_id     = var.subscription_id,
      resource_group_name = var.resource_group_name,
      app_gateway_name    = local.app_gateway_name,
      secret_json = base64encode(jsonencode({
        clientId                       = "${azuread_service_principal.aks.application_id}",
        clientSecret                   = "${azuread_service_principal_password.aks.value}",
        subscriptionId                 = "${var.subscription_id}",
        tenantId                       = "${data.azurerm_client_config.current.tenant_id}",
        activeDirectoryEndpointUrl     = "https://login.microsoftonline.com",
        resourceManagerEndpointUrl     = "https://management.azure.com/",
        activeDirectoryGraphResourceId = "https://graph.windows.net/",
        sqlManagementEndpointUrl       = "https://management.core.windows.net:8443/",
        galleryEndpointUrl             = "https://gallery.azure.com/",
        managementEndpointUrl          = "https://management.core.windows.net/",
      }))
    })}"
  ]
}

# Helm Releases

resource "helm_release" "building_blocks" {
  for_each      = local.services
  repository    = "https://cdcgov.github.io/phdi-charts/"
  name          = "phdi-${terraform.workspace}-${each.key}"
  chart         = "${each.key}-chart"
  recreate_pods = true
  depends_on    = [helm_release.agic]

  set {
    name  = "image.tag"
    value = "latest"
  }

  set {
    name  = "databasePassword"
    value = azurerm_postgresql_flexible_server.mpi.administrator_password
  }

  set {
    name  = "databaseName"
    value = azurerm_postgresql_flexible_server_database.mpi.name
  }

  set {
    name  = "databaseHost"
    value = azurerm_postgresql_flexible_server.mpi.fqdn
  }

  set {
    name  = "smartyAuthId"
    value = azurerm_key_vault_secret.smarty_auth_id.value
  }

  set {
    name  = "smartyToken"
    value = azurerm_key_vault_secret.smarty_auth_token.value
  }
}
