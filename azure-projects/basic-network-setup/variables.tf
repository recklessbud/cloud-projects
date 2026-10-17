#Variable definitions for the Basic Network Setup Terraform configuration
# These variables allow customization of the deployment without modifying the main configuration


variable "location" {
  description = "The azure region where all resources will be created"
  type        = string
  default     = "East US"

}


variable "environment" {
  description = "Environment (dev, stage, prod)"
  type        = string
  default     = "dev"
}

# resource naming
variable "resource_group_name" {
  description = "The name of the resource group to create"
  type        = string
  default     = "basic-network-rg"
}


variable "virtual_network_name" {
  description = "The name of the virtual network to create"
  type        = string
  default     = "basic-network-vnet"
}


# network configs
variable "vnet_address_space" {
  description = "address space for the virtual network in CIDR notation"
  type        = list(string)
  default     = ["10.0.0.0/16"]

  validation {
    condition = alltrue([
      for cidr in var.vnet_address_space : can(cidrhost(cidr, 0))
    ])
    error_message = "At least one CIDR block must be specified"
  }
}

#subnet configs
variable "frontend_subnet_name" {
  description = "The name of the frontend subnet to create"
  type        = string
  default     = "frontend-subnet"
}

variable "frontend_subnet_address_prefix" {
  description = "The address prefix for the frontend subnet in CIDR notation"
  type        = string
  default     = "10.0.1.0/24"

  validation {
    condition     = can(cidrhost(var.frontend_subnet_address_prefix, 0))
    error_message = "Must be a valid CIDR block for the subnet"
  }

}




variable "backend_subnet_name" {
  description = "The name of the backend subnet to create"
  type        = string
  default     = "backend-subnet"
}

variable "backend_subnet_address_prefix" {
  description = "The address prefix for the backend subnet in CIDR notation"
  type        = string
  default     = "10.0.2.0/24"

  validation {
    condition     = can(cidrhost(var.backend_subnet_address_prefix, 0))
    error_message = "Must be a valid CIDR block for the subnet"
  }

}




variable "database_subnet_name" {
  description = "The name of the database subnet to create"
  type        = string
  default     = "database-subnet"
}

variable "database_subnet_address_prefix" {
  description = "The address prefix for the database subnet in CIDR notation"
  type        = string
  default     = "10.0.3.0/24"

  validation {
    condition     = can(cidrhost(var.database_subnet_address_prefix, 0))
    error_message = "Must be a valid CIDR block for the subnet"
  }

}


variable "frontend_allowed_ports" {
  description = " The list of allowed ports for the frontend subnet"
  type        = list(string)
  default     = ["80", "443"]

  validation {
    condition = alltrue([
      for port in var.frontend_allowed_ports : can(tonumber(port)) && tonumber(port) >= 1 && tonumber(port) <= 65535
    ])
    error_message = "All ports must be valid port numbers between 1 and 65535."

  }
}


variable "backend_app_port" {
  description = "The port for the backend application"
  type        = string
  default     = "8080"

  validation {
    condition     = can(tonumber(var.backend_app_port)) && tonumber(var.backend_app_port) >= 1 && tonumber(var.backend_app_port) <= 65535
    error_message = "Backend application port must be a valid port number between 1 and 65535."
  }
}


variable "database_port" {
  description = "Port number for database traffic from backend (e.g., 5432 for PostgreSQL, 3306 for MySQL)"
  type        = string
  default     = "5432"

  validation {
    condition     = can(tonumber(var.database_port)) && tonumber(var.database_port) >= 1 && tonumber(var.database_port) <= 65535
    error_message = "Database port must be a valid port number between 1 and 65535."
  }
}


variable "tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default = {
    purpose = "recipe"
    tier    = "networking"
  }

  validation {
    condition     = length(var.tags) <= 50
    error_message = "Maximum of 50 tags are allowed per resource."
  }
}

# Random suffix configuration
variable "use_random_suffix" {
  description = "Whether to append a random suffix to resource names for uniqueness"
  type        = bool
  default     = true
}
