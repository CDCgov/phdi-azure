variable "subscription_id" {
  description = "value of the Azure Subscription ID to use"
}

variable "location" {
  description = "value of the Azure location to deploy to"
  default     = "Central US"
}

variable "resource_group_name" {
  description = "value of the Azure resource group to deploy to"
}

variable "smarty_auth_id" {
  description = "value of the SmartyStreets Auth ID"
}

variable "smarty_auth_token" {
  description = "value of the SmartyStreets Auth Token"
}

variable "smarty_license_type" {
  type        = string
  description = "value of the SmartyStreets license type to use"
}

variable "client_id" {
  description = "Client ID"
}

variable "object_id" {
  description = "Object ID"
}

variable "use_oidc" {
  type        = bool
  description = "Use OIDC for authentication."
  default     = false
}

variable "k8s_vnet_address_space" {
  type        = string
  description = "Ip address space for kubernetes vnet"
  default     = "10.30.0.0/16"
}

variable "k8s_subnet_address_prefix" {
  type        = string
  description = "Ip address space for kubernetes subnet vnet"
  default     = "10.30.1.0/24"
}

variable "app_gateway_subnet_address_prefix" {
  type        = string
  description = "Subnet server IP address."
  default     = "10.30.2.0/24"
}

variable "app_gateway_sku" {
  type        = string
  description = "Name of the Application Gateway SKU"
  default     = "Standard_v2"
}

variable "app_gateway_tier" {
  type        = string
  description = "Tier of the Application Gateway tier"
  default     = "Standard_v2"
}

variable "aks_agent_os_disk_size" {
  type        = number
  description = "Disk size (in GB) to provision for each of the agent pool nodes. This value ranges from 0 to 1023. Specifying 0 applies the default disk size for that agentVMSize."
  default     = 40
}

variable "aks_agent_count" {
  type        = number
  description = "The number of agent nodes for the cluster."
  default     = 3
}

variable "aks_agent_vm_size" {
  type        = string
  description = "VM size"
  default     = "Standard_D2_v2"
}

variable "aks_service_cidr" {
  type        = string
  description = "CIDR notation IP range from which to assign service cluster IPs"
  default     = "10.0.0.0/16"
}

variable "aks_dns_service_ip" {
  type        = string
  description = "DNS server IP address"
  default     = "10.0.0.10"
}

variable "aks_enable_rbac" {
  type        = bool
  description = "Enable RBAC on the AKS cluster. Defaults to false."
  default     = "false"
}

variable "msi_id" {
  type        = string
  description = "The Managed Service Identity ID. Set this value if you're running this example using Managed Identity as the authentication method."
  default     = null
}

variable "vm_username" {
  type        = string
  description = "User name for the VM"
  default     = "aks_user"
}
