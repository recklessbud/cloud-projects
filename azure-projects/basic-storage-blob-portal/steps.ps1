#Preparation
# Login to Azure and set default subscription
az login

# Set environment variables for Azure resources
$RESOURCE_GROUP="rg-storage-demo-$(Get-Random -Minimum 100000 -Maximum 999999)"
$LOCATION="eastus"
$STORAGE_ACCOUNT="sa$(Get-Random -Minimum 100000 -Maximum 999999)"
$SUBSCRIPTION_ID= az account show --query id --output tsv

# Generate unique suffix for resource naming
RANDOM_SUFFIX=$(Get-Random -Minimum 1000 -Maximum 9999)

# Create resource group for storage resources
az group create --name ${RESOURCE_GROUP} --location ${LOCATION} --tags purpose=demo environment=learning

Write-Output "✅ Resource group created: ${RESOURCE_GROUP}"
Write-Output "✅ Storage account name: ${STORAGE_ACCOUNT}"

# Create general-purpose v2 storage account with security hardening
az storage account create `
    --name ${STORAGE_ACCOUNT} `
    --resource-group ${RESOURCE_GROUP} `
    --location ${LOCATION} `
    --sku Standard_LRS `
    --kind StorageV2 `
    --access-tier Hot `
    --min-tls-version TLS1_2 `
    --allow-blob-public-access false `
    --tags purpose=demo environment=learning

write-output "✅ Storage account created with TLS 1.2 enforcement and secure defaults"

# Get current user ID for RBAC assignment
CURRENT_USER_ID=$(az ad signed-in-user show --query id --output tsv)

# Assign Storage Blob Data Contributor role to current user
az role assignment create `
    --role "Storage Blob Data Contributor" `
    --assignee ${CURRENT_USER_ID} `
    --scope "/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RESOURCE_GROUP}/providers/Microsoft.Storage/storageAccounts/${STORAGE_ACCOUNT}"

write-output "✅ RBAC permissions configured for blob data access"
Write-Output "Note: Role assignment may take 1-2 minutes to propagate"


# Wait for RBAC propagation before creating containers
write-output "Waiting 30 seconds for RBAC permissions to propagate..."
sleep 30

# Create containers for different content types
az storage container create `
    --name "documents" `
    --account-name ${STORAGE_ACCOUNT} `
    --auth-mode login

az storage container create `
    --name "images" `
    --account-name ${STORAGE_ACCOUNT} `
    --auth-mode login

az storage container create `
    --name "backups" `
    --account-name ${STORAGE_ACCOUNT} `
    --auth-mode login

write-output "✅ Three containers created for organized file storage"


# Create sample files for testing (if not available)
write-output "This is a sample document for testing blob storage capabilities." > sample-document.txt
write-output '{"app": "demo", "environment": "test", "version": "1.0"}' > config.json

# Upload files to appropriate containers with hierarchical naming
az storage blob upload `
    --file sample-document.txt `
    --name "sample-document.txt" `
    --container-name "documents" `
    --account-name ${STORAGE_ACCOUNT} `
    --auth-mode login

az storage blob upload `
    --file config.json `
    --name "settings/config.json" `
    --container-name "documents" `
    --account-name ${STORAGE_ACCOUNT} `
    --auth-mode login

write-output "✅ Sample files uploaded successfully to blob storage"

# Create download directory
mkdir -p downloads

# Download files from blob storage with verification
az storage blob download `
    --name "sample-document.txt" `
    --container-name "documents" `
    --file "./downloads/downloaded-document.txt" `
    --account-name ${STORAGE_ACCOUNT} `
    --auth-mode login

Write-Output "all done good onto testing"

# Check storage account status and configuration
az storage account show `
    --name ${STORAGE_ACCOUNT} `
    --resource-group ${RESOURCE_GROUP} `
    --query "{name:name,sku:sku.name,location:location,provisioningState:provisioningState,minimumTlsVersion:minimumTlsVersion,allowBlobPublicAccess:allowBlobPublicAccess}" `
    --output table

#Expected output: Storage account shows "Succeeded" provisioning state, TLS 1.2 minimum version, disabled public access, and three containers (documents, images, backups) are listed.

# List all containers with metadata
az storage container list `
    --account-name ${STORAGE_ACCOUNT} `
    --auth-mode login `
    --output table


# Clean up in portal(console) to get used to