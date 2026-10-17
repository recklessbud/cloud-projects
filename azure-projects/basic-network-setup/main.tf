# Azure Basic Network Setup with Virtual Network and Subnets
# This configuration creates a three-tier network architecture with proper security controls
# following Azure Well-Architected Framework networking best practices


resource "random_id" "suffix" {
  byte_length = 4
}

locals {
  resource_group_name = "${var.resource_group_name}-${random_id.suffix.hex}"
  vnet_name           = "${var.virtual_network_name}-${random_id.suffix.hex}"

  common_tags = merge(var.tags, {
    environment   = var.environment
    managed_by    = "terraform"
    recipe_id     = "a3f2b8e1"
    recipe_name   = "basic-network-setup-vnet-subnets"
    creation_date = formatdate("YYYY-MM-DD", timestamp())
  })
}


resource "azurerm_resource_group" "main" {
  name     = local.resource_group_name
  location = var.location

  tags = merge(local.common_tags, {
    resource_type = "resource-group"
    description   = "Resource group for basic network setup demonstration"
  })
}


resource "azurerm_virtual_network" "main" {
  name                = local.vnet_name
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  address_space       = var.vnet_address_space

  tags = merge(local.common_tags, {
    resource_type = "virtual-network"
    description   = "Virtual network for basic network setup demonstration"
    address_space = join(",", var.vnet_address_space)
  })

}


resource "azurerm_subnet" "frontend" {
  name                 = var.frontend_subnet_name
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [var.frontend_subnet_address_prefix]

  depends_on = [azurerm_virtual_network.main]
}


resource "azurerm_subnet" "backend" {
  name                 = var.backend_subnet_name
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [var.backend_subnet_address_prefix]

  depends_on = [azurerm_virtual_network.main]
}

resource "azurerm_subnet" "database" {
  name                 = var.database_subnet_name
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [var.database_subnet_address_prefix]

  depends_on = [azurerm_virtual_network.main]
}


resource "azurerm_network_security_group" "frontend" {
  name                = "nsg-${var.frontend_subnet_name}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  tags = merge(local.common_tags, {
    resource_type = "network-security-group"
    tier          = "frontend"
    description   = "NSG for frontend subnet allowing web traffic"
  })
}


resource "azurerm_network_security_rule" "frontend_allow_web" {
  count                       = length(var.frontend_allowed_ports)
  name                        = "allow-web-${var.frontend_allowed_ports[count.index]}"
  priority                    = 1000 + count.index
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = var.frontend_allowed_ports[count.index]
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.main.name
  network_security_group_name = azurerm_network_security_group.frontend.name
}


resource "azurerm_network_security_group" "backend" {
  name                = "nsg-${var.backend_subnet_name}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  tags = merge(local.common_tags, {
    resource_type = "network-security-group"
    tier          = "backend"
    description   = "NSG for backend subnet allowing only frontend traffic"
  })
}

resource "azurerm_network_security_rule" "backend_allow_frontend" {
  name                        = "allow-frontend"
  priority                    = 1000
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = var.backend_app_port
  source_address_prefix       = var.frontend_subnet_address_prefix
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.main.name
  network_security_group_name = azurerm_network_security_group.backend.name
}


resource "azurerm_network_security_group" "database" {
  name                = "nsg-${var.database_subnet_name}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  tags = merge(local.common_tags, {
    resource_type = "network-security-group"
    tier          = "backend"
    description   = "NSG for database subnet allowing only backend traffic"
  })
}


resource "azurerm_network_security_rule" "database_allow_backend" {
  name                        = "allow-backend"
  priority                    = 1000
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = var.database_port
  source_address_prefix       = var.backend_subnet_address_prefix
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.main.name
  network_security_group_name = azurerm_network_security_group.database.name
}


resource "azurerm_subnet_network_security_group_association" "frontend" {
  subnet_id                 = azurerm_subnet.frontend.id
  network_security_group_id = azurerm_network_security_group.frontend.id

  depends_on = [azurerm_network_security_rule.frontend_allow_web]
}


resource "azurerm_subnet_network_security_group_association" "backend" {
  subnet_id                 = azurerm_subnet.backend.id
  network_security_group_id = azurerm_network_security_group.backend.id

  depends_on = [
    azurerm_network_security_rule.backend_allow_frontend
  ]
}

# Associate Database NSG with Database Subnet
# This provides the highest level of network security for data tier resources
resource "azurerm_subnet_network_security_group_association" "database" {
  subnet_id                 = azurerm_subnet.database.id
  network_security_group_id = azurerm_network_security_group.database.id

  depends_on = [
    azurerm_network_security_rule.database_allow_backend
  ]
}