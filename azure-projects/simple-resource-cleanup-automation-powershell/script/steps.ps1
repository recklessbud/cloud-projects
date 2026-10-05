# scripts to write the reource cleanup shell

# ***PREPARATION***
$RESOURCE_GROUP="rg-cleanup-demo-3"
$LOCATION="eastus"
$SUBSCRIPTION_ID= az account show --query "id" --output tsv

#create resource group for automation resources
az group --name $RESOURCE_GROUP --location $LOCATION --subscription $SUBSCRIPTION_ID --tags purpose=automation environment=dev project=resource-cleanup

Write-Output "Resource group $RESOURCE_GROUP created"

$AUTOMATION_ACCOUNT="automation-cleanup-33"

# ***STEPS***

## create an Azure Automation account with system assigned identity
az automation account create --name $AUTOMATION_ACCOUNT --resource-group $RESOURCE_GROUP --location $LOCATION --assign-identity --tags environment=demo purpose=cleanup

Write-Output "Automation account $AUTOMATION_ACCOUNT created"

# managed identity principal ID
$PRINCIPAL_ID= az automation account show --name $AUTOMATION_ACCOUNT --resource-group $RESOURCE_GROUP --query "identity.principalId" --output tsv

# create role assignment

az role assignment create --assignee $PRINCIPAL_ID --role "Contributor" --scope "/subscriptions/$SUBSCRIPTION_ID"
 Write-Output "contributor permissions assigned"


# create a runbook for cleanup
@"
param(
    [int]$DaysOld = 7,
    [string]$Environment = "dev",
    [bool]$DryRun = $true
)

# Ensure no context inheritance and connect using managed identity
Disable-AzContextAutosave -Scope Process
$AzureContext = (Connect-AzAccount -Identity).context
$AzureContext = Set-AzContext -SubscriptionName $AzureContext.Subscription `
    -DefaultProfile $AzureContext

Write-Output "Starting resource cleanup process..."
Write-Output "Parameters: DaysOld=$DaysOld, Environment=$Environment, DryRun=$DryRun"

# Calculate cutoff date
$cutoffDate = (Get-Date).AddDays(-$DaysOld)
Write-Output "Resources created before $cutoffDate will be considered for cleanup"

# Get all resource groups with specified environment tag
$resourceGroups = Get-AzResourceGroup | Where-Object {
    $_.Tags.Environment -eq $Environment -and
    $_.Tags.AutoCleanup -eq "true"
}

$cleanupSummary = @{
    ResourceGroupsProcessed = 0
    ResourcesFound = 0
    ResourcesDeleted = 0
    Errors = @()
}

foreach ($rg in $resourceGroups) {
    Write-Output "Processing resource group: $($rg.ResourceGroupName)"
    $cleanupSummary.ResourceGroupsProcessed++
    
    try {
        # Get resources older than cutoff date
        $oldResources = Get-AzResource -ResourceGroupName $rg.ResourceGroupName | Where-Object {
            $_.Tags.DoNotDelete -ne "true" -and
            $_.CreatedTime -ne $null -and
            [DateTime]$_.CreatedTime -lt $cutoffDate
        }
        
        $cleanupSummary.ResourcesFound += $oldResources.Count
        
        foreach ($resource in $oldResources) {
            Write-Output "Found old resource: $($resource.Name) (Type: $($resource.ResourceType), Created: $($resource.CreatedTime))"
            
            if (-not $DryRun) {
                Write-Output "Deleting resource: $($resource.Name)"
                Remove-AzResource -ResourceId $resource.ResourceId -Force
                $cleanupSummary.ResourcesDeleted++
            } else {
                Write-Output "DRY RUN: Would delete resource: $($resource.Name)"
            }
        }
    }
    catch {
        $errorMsg = "Error processing resource group $($rg.ResourceGroupName): $($_.Exception.Message)"
        Write-Error $errorMsg
        $cleanupSummary.Errors += $errorMsg
    }
}

# Output summary
Write-Output "Cleanup Summary:"
Write-Output "- Resource Groups Processed: $($cleanupSummary.ResourceGroupsProcessed)"
Write-Output "- Resources Found: $($cleanupSummary.ResourcesFound)"
Write-Output "- Resources Deleted: $($cleanupSummary.ResourcesDeleted)"
Write-Output "- Errors: $($cleanupSummary.Errors.Count)"

if ($cleanupSummary.Errors.Count -gt 0) {
    Write-Output "Errors encountered:"
    $cleanupSummary.Errors | ForEach-Object { Write-Output "  - $_" }
}

"@ | Set-Content -Path runbook.ps1


#import and create runbook
az automation runbook create --automation-account-name $AUTOMATION_ACCOUNT --resource-group $RESOURCE_GROUP --name "ResourceCleanupRunbook" --type "PowerShell" --description "Automated cleanup of old Azure resources"
Write-Output "Powershelll runbook created successfully"

#Upload and Publish the Runbook
$runbookContent = Get-Content -Path ".\runbook.ps1" -Raw
az automation runbook replace-content --automation-account-name $AUTOMATION_ACCOUNT --resource-group $RESOURCE_GROUP --name "ResourceCleanupRunbook" --content $runbookContent
az automation runbook publish --automation-account-name $AUTOMATION_ACCOUNT --resource-group $RESOURCE_GROUP --name "ResourceCleanupRunbook"

Write-Output "Powershelll runbook uploadeda and punlished successfully"


##**OPTIONAL**
#test-resources
$TEST_RG="rg-cleanup-test-334"

az group create --name $TEST_RG --location $LOCATION --tags environment=dev AutoCleanup=true project=testing createdBy=automation

$TEST_STORAGE="rg-cleanup-sttest"

az storage account create --name $TEST_STORAGE --location $LOCATION --sku Standard_LRS --tags environment=dev AutoCleanup=true purpose=testing

$PROTECTED_STORAGE="stprotected"

az storage account create --name $PROTECTED_STORAGE --resource-group $TEST_RG --location $LOCATION --sku Standard_LRS --tags Environment=dev DoNotDelete=true purpose=production

Write-Output "✅ Test resources created with appropriate tags"

# Create a weekly schedule using PowerShell (more reliable for weekly schedules)
az automation runbook start --automation-account-name $AUTOMATION_ACCOUNT --resource-group $RESOURCE_GROUP --name "ResourceCleanupRunbook" --parameters '{"PowerShellScript": " New-AzAutomationSchedule -AutomationAccountName \"'$AUTOMATION_ACCOUNT'\" -ResourceGroupName \"'$RESOURCE_GROUP'\" -Name \"WeeklyCleanupSchedule\" -Description \"Weekly cleanup of dev resources\" -StartTime (Get-Date).AddDays(1).Date.AddHours(2) -WeekInterval 1 -DaysOfWeek Sunday " }'
Write-Output "✅ Weekly cleanup schedule creation initiated"