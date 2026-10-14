#preparations

# Login to Azure and set default subscription
az login

# Set environment variables for Azure resources
$RG="rg-service-health-$(Get-Random -Minimum 100000 -Maximum 999999)"
$LOCATION="southafricanorth"
$SUBS_ID=az account show --query id --output tsv
# $RANDOM=Get-Random -Minimum 100000 -Maximum 999999
$NOTIFICATION_EMAIL="example@some.com"
# $NOTIFICATION_PHONE="+1234567890"

# Create resource group
az group create --name $RG --location $LOCATION --tags purpose=service-health-monitoring environment=prod

# Create action group register email
az monitor action-group create --name "ServiceHealthAlerts" --resource-group $RG --short-name "SvcHealth"  --action email "admin-mail" $NOTIFICATION_EMAIL


# Get action group ID
$ACTION_GROUP_ID=$(az monitor action-group show `
    --name "ServiceHealthAlerts" `
    --resource-group ${RESOURCE_GROUP} `
    --query id --output tsv)

# Create alert rule for service issues affecting your subscription
az monitor activity-log alert create `
    --name "ServiceIssueAlert" `
    --resource-group ${RG} `
    --condition category=ServiceHealth `
    --action-group ${ACTION_GROUP_ID} `
    --description "Alert for Azure service issues affecting subscription"

# Create alert rule for planned maintenance notifications
az monitor activity-log alert create `
    --name "PlannedMaintenanceAlert" `
    --resource-group ${RG} `
    --condition category=ServiceHealth `
    --action-group ${ACTION_GROUP_ID} `
    --description "Alert for planned Azure maintenance events"


# Create alert rule for health advisories
az monitor activity-log alert create `
    --name "HealthAdvisoryAlert" `
    --resource-group ${RG} `
    --condition category=ServiceHealth `
    --action-group ${ACTION_GROUP_ID} `
    --description "Alert for Azure health advisories and recommendations"

# Create targeted alert for critical Azure services
az monitor activity-log alert create `
    --name "CriticalServicesAlert" `
    --resource-group ${RG} `
    --condition category=ServiceHealth `
    --action-group ${ACTION_GROUP_ID} `
    --description "Alert for critical Azure services: Virtual Machines, Storage, Networking" `
    --scope "/subscriptions/${SUBS_ID}"


## TESTING

# List all activity log alert rules in the resource group
az monitor activity-log alert list `
    --resource-group ${RG} `
    --output table

# Check specific alert rule details
az monitor activity-log alert show `
    --name "ServiceIssueAlert" `
    --resource-group ${RG} `
    --query '{Name:name, Enabled:enabled, Condition:condition, ActionGroups:actions.actionGroups}'


# Test action group by triggering a test notification
az monitor action-group test-notifications create `
    --action-group-name "ServiceHealthAlerts" `
    --resource-group ${RG} `
    --alert-type servicehealth
