param(
    [int] = 7,
    [string] = "dev",
    [bool] = True
)

# Ensure no context inheritance and connect using managed identity
Disable-AzContextAutosave -Scope Process
 = (Connect-AzAccount -Identity).context
 = Set-AzContext -SubscriptionName .Subscription 
    -DefaultProfile 

Write-Output "Starting resource cleanup process..."
Write-Output "Parameters: DaysOld=, Environment=, DryRun="

# Calculate cutoff date
 = (Get-Date).AddDays(-)
Write-Output "Resources created before  will be considered for cleanup"

# Get all resource groups with specified environment tag
 = Get-AzResourceGroup | Where-Object {
    .Tags.Environment -eq  -and
    .Tags.AutoCleanup -eq "true"
}

 = @{
    ResourceGroupsProcessed = 0
    ResourcesFound = 0
    ResourcesDeleted = 0
    Errors = @()
}

foreach ( in ) {
    Write-Output "Processing resource group: "
    .ResourceGroupsProcessed++
    
    try {
        # Get resources older than cutoff date
         = Get-AzResource -ResourceGroupName .ResourceGroupName | Where-Object {
            .Tags.DoNotDelete -ne "true" -and
            .CreatedTime -ne  -and
            [DateTime].CreatedTime -lt 
        }
        
        .ResourcesFound += .Count
        
        foreach ( in ) {
            Write-Output "Found old resource:  (Type: , Created: )"
            
            if (-not ) {
                Write-Output "Deleting resource: "
                Remove-AzResource -ResourceId .ResourceId -Force
                .ResourcesDeleted++
            } else {
                Write-Output "DRY RUN: Would delete resource: "
            }
        }
    }
    catch {
         = "Error processing resource group : "
        Write-Error 
        .Errors += 
    }
}

# Output summary
Write-Output "Cleanup Summary:"
Write-Output "- Resource Groups Processed: "
Write-Output "- Resources Found: "
Write-Output "- Resources Deleted: "
Write-Output "- Errors: 0"

if (.Errors.Count -gt 0) {
    Write-Output "Errors encountered:"
    .Errors | ForEach-Object { Write-Output "  - " }
}

