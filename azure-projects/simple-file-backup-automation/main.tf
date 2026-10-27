# main configuration

resource "random_string" "suffix" {
  length  = 6
  upper   = false
  special = false
  numeric = true
}

data "azurerm_client_config" "current" {}

resource "azurerm_resource_group" "backup" {
  name     = "${var.resource_group_name}-${random_string.suffix.result}"
  location = var.location
  tags     = var.common_tags
}
resource "azurerm_storage_account" "backup" {
  name                     = var.storage_account_name != "" ? var.storage_account_name : "st${var.workload}${random_string.suffix.result}"
  resource_group_name      = azurerm_resource_group.backup.name
  location                 = azurerm_resource_group.backup.location
  account_tier             = var.storage_account_tier
  access_tier              = var.storage_access_tier
  account_replication_type = var.storage_replication_type

  https_traffic_only_enabled      = var.enable_https_traffic_only
  min_tls_version                 = var.min_tls_version
  allow_nested_items_to_be_public = var.allow_blob_public_access

  blob_properties {
    versioning_enabled = true

    delete_retention_policy {
      days = 7
    }

    container_delete_retention_policy {
      days = 7
    }
  }

  network_rules {
    default_action = "Allow"
  }
}


resource "azurerm_storage_container" "backup_files" {
  name                  = var.container_name
  storage_account_name  = azurerm_storage_account.backup.name
  container_access_type = "private"

  metadata = {
    purpose     = "backup"
    created     = timestamp()
    environment = var.environment
  }
  depends_on = [azurerm_storage_account.backup]

}


resource "azurerm_log_analytics_workspace" "backup" {
  count               = var.enable_storage_logging || var.enable_logic_apps_logging ? 1 : 0
  name                = "law-${var.workload}-${random_string.suffix.result}"
  location            = azurerm_resource_group.backup.location
  resource_group_name = azurerm_resource_group.backup.name
  sku                 = "PerGB2018"
  retention_in_days   = 30

  tags = merge(var.common_tags, {
    Component = "Monitoring"
    Purpose   = "Logging"
  })
}

resource "azurerm_logic_app_workflow" "backup" {
  name                = "la-${var.workload}-${random_string.suffix.result}"
  location            = azurerm_resource_group.backup.location
  resource_group_name = azurerm_resource_group.backup.name

  workflow_schema  = "https://schema.management.azure.com/providers/Microsoft.Logic/schemas/2016-06-01/workflowdefinition.json#"
  workflow_version = "1.0.0.0"
identity {
  type = "SystemAssigned"
} 
workflow_parameters = {
  "$connections" = jsonencode({
    type  = "Object"
    value = {}
  })

  "StorageAccountName" = jsonencode({
    type  = "String"
    value = azurerm_storage_account.backup.name
  })

  "containerName" = jsonencode({
    type  = "String"
    value = azurerm_storage_container.backup_files.name
  })
}
  tags = merge(var.common_tags, {
    Component = "Automation"
    Purpose   = "BackupWorkflow"
  })
}


resource "azurerm_logic_app_trigger_recurrence" "backup_trigger" {
  logic_app_id = azurerm_logic_app_workflow.backup.id
  name         = "backupTrigger"
  frequency    = var.backup_schedule_frequency
  interval     = var.backup_schedule_interval
  time_zone    = var.time_zone

  schedule {
    at_these_hours   = [var.backup_time_hour]
    at_these_minutes = [var.backup_time_minute]
  }

}

resource "azurerm_logic_app_action_custom" "initialize_backup_status" {
  name         = "InitializeBackupStatus"
  logic_app_id = azurerm_logic_app_workflow.backup.id

  body = jsonencode({
    type = "InitialVariable"
    inputs = {
      variables = [
        {
          name  = "BackupStatus"
          type  = "String"
          value = "Starting backup process at @{utcNow()}"
        }
      ]
    }
    runAfter = {}
  })

  depends_on = [azurerm_logic_app_trigger_recurrence.backup_trigger]
}

resource "azurerm_logic_app_action_http" "create_backup_log" {
  name         = "CreateBackupLog"
  logic_app_id = azurerm_log_analytics_workspace.backup[0].id
  method       = "PUT"
  uri          = "https://${azurerm_storage_account.backup.name}.blob.core.windows.net/${azurerm_storage_container.backup_files.name}/backup-log-@{formatDateTime(utcNow(), 'yyyy-MM-dd-HH-mm')}.txt"

  headers = {
    "x-ms-blob-type" = "BlockBlob"
    "Content-Type"   = "text/plain"
    "x-ms-version"   = "2019-12-12"
  }

  body = "Backup process initiated at @{utcNow()} - Status: @{variables('BackupStatus')}"

  run_after {
    action_name   = azurerm_logic_app_action_custom.initialize_backup_status.name
    action_result = "Succeeded"


  }
}

resource "azurerm_monitor_diagnostic_setting" "storage" {
  count                      = var.enable_storage_logging ? 1 : 0
  name                       = "storagediag-${var.workload}-${random_string.suffix.result}"
  target_resource_id         = "${azurerm_storage_account.backup.id}/blobServices/default"
  log_analytics_workspace_id = azurerm_log_analytics_workspace.backup[0].id

  enabled_log {
    category = "StorageRead"
  }
  enabled_log {
    category = "StorageDelete"
  }

  enabled_log {
    category = "StorageWrite"
  }

  metric {
    category = "Transaction"
    enabled  = true

    retention_policy {
      enabled = true
      days    = var.log_retention_days
    }
  }

  metric {
    category = "Capacity"
    enabled  = true

    retention_policy {
      enabled = true
      days    = var.log_retention_days
    }
  }
}

resource "azurerm_role_assignment" "logic_app_storage" {
  scope                = azurerm_storage_account.backup.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_logic_app_workflow.backup.identity[0].principal_id

  depends_on = [azurerm_logic_app_workflow.backup, azurerm_storage_account.backup]
}


resource "azurerm_logic_app_workflow" "backup_identity" {
  name                = azurerm_logic_app_workflow.backup.name
  location            = azurerm_resource_group.backup.location
  resource_group_name = azurerm_resource_group.backup.name
  identity {
    type = "SystemAssigned"
  }

  workflow_schema     = azurerm_logic_app_workflow.backup.workflow_schema
  workflow_version    = azurerm_logic_app_workflow.backup.workflow_version
  workflow_parameters = azurerm_logic_app_workflow.backup.workflow_parameters
  tags                = azurerm_logic_app_workflow.backup.tags

  lifecycle {
    replace_triggered_by = [azurerm_log_analytics_workspace.backup]
  }
}

resource "time_sleep" "wait_for_resources" {
  depends_on = [
    azurerm_storage_account.backup,
    azurerm_storage_container.backup_files,
    azurerm_logic_app_workflow.backup
  ]

  create_duration = "30s"
}