
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
