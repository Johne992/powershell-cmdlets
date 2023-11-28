# This script is used to apply the networking subnets for the NCC Serverless Databricks workspace to a storage account.
$SubscriptionName = ""
$storageAccountName = ""
$stoageAccountRG = ""
$nccSubnets = @(
    )


# Set subscription context
Set-AzContext -SubscriptionName $SubscriptionName

# Loop over network rules and apply to storage account
foreach ($subnet in $nccSubnets) {
    # Add subnet to storage account
    Add-AzStorageAccountNetworkRule -ResourceGroupName $stoageAccountRG -Name $storageAccountName -VirtualNetworkResourceId $subnet

}
