terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>3.0"
    }
  }
}

provider "azurerm" {
  features {}
}

# Resource Group
resource "azurerm_resource_group" "main" {
  name     = "shopsphere-rg"
  location = "East US"
  
  tags = {
    environment = "production"
    project     = "shopsphere"
  }
}

# Container Registry
resource "azurerm_container_registry" "main" {
  name                = "shopsphereacrregistry"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  sku                 = "Basic"
  admin_enabled       = true
  
  tags = {
    environment = "production"
    project     = "shopsphere"
  }
}

# AKS Cluster
resource "azurerm_kubernetes_cluster" "main" {
  name                = "shopsphere-aks"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  dns_prefix          = "shopsphere"

  default_node_pool {
    name       = "default"
    node_count = 3
    vm_size    = "Standard_D2_v2"
    
    enable_auto_scaling = true
    min_count          = 1
    max_count          = 5
  }

  identity {
    type = "SystemAssigned"
  }

  network_profile {
    network_plugin = "kubenet"
  }
  
  tags = {
    environment = "production"
    project     = "shopsphere"
  }
}

# PostgreSQL Server
resource "azurerm_postgresql_server" "main" {
  name                = "shopsphere-postgresql"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  administrator_login          = "psqladmin"
  administrator_login_password = "H@Sh1CoR3!"

  sku_name   = "GP_Gen5_2"
  version    = "11"
  storage_mb = 51200

  backup_retention_days        = 7
  geo_redundant_backup_enabled = false
  auto_grow_enabled            = true

  public_network_access_enabled    = false
  ssl_enforcement_enabled          = true
  ssl_minimal_tls_version_enforced = "TLS1_2"
  
  tags = {
    environment = "production"
    project     = "shopsphere"
  }
}

# PostgreSQL Database
resource "azurerm_postgresql_database" "main" {
  name                = "shopdb"
  resource_group_name = azurerm_resource_group.main.name
  server_name         = azurerm_postgresql_server.main.name
  charset             = "UTF8"
  collation           = "English_United States.1252"
}

# Redis Cache
resource "azurerm_redis_cache" "main" {
  name                = "shopsphere-redis"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  capacity            = 2
  family              = "C"
  sku_name            = "Standard"
  enable_non_ssl_port = false
  minimum_tls_version = "1.2"

  redis_configuration {
  }
  
  tags = {
    environment = "production"
    project     = "shopsphere"
  }
}

# Application Gateway
resource "azurerm_public_ip" "main" {
  name                = "shopsphere-pip"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  allocation_method   = "Static"
  sku                 = "Standard"
  
  tags = {
    environment = "production"
    project     = "shopsphere"
  }
}

# Outputs
output "kube_config" {
  value = azurerm_kubernetes_cluster.main.kube_config_raw
  sensitive = true
}

output "container_registry_login_server" {
  value = azurerm_container_registry.main.login_server
}

output "postgresql_fqdn" {
  value = azurerm_postgresql_server.main.fqdn
}

output "redis_hostname" {
  value = azurerm_redis_cache.main.hostname
}