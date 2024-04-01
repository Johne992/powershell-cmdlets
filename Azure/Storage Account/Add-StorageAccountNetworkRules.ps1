<#
.SYNOPSIS
    Add-StorageAccountNetworkRules.ps1

.DESCRIPTION
    This script sets the Azure context to a specific subscription, retrieves the network rule set for a specified storage account, adds a new virtual network rule to the existing rule set, and then applies the updated rule set to the storage account.

.AUTHOR
    John Lewis

.DATE
    04/01/2024

.NOTES
    Tags: powershell, azure, storage-account, network-rules
#>

# Specify the resource group and storage account name
$subscriptionName = "<Your-Subscription-Name>"
$resourceGroupName = "<Your-Resource-Group-Name>"
$storageAccountName = "<Your-Storage-Account-Name>"

#Set Context
Set-AzContext -SubscriptionName $subscriptionName

#Get Storage Account Network Ruleset
$networkRules = Get-AzStorageAccountNetworkRuleSet  -ResourceGroupName $resourceGroupName -Name $storageAccountName

# Add the new subnet to the existing network ruleset
$virtualNetworkResourceId = "<Your-Virtual-Network-Resource-Id>"
$networkRules.VirtualNetworkRules += @{VirtualNetworkResourceId = $virtualNetworkResourceId; Action = "allow" }

Add-AzStorageAccountNetworkRule -ResourceGroupName $resourceGroupName -Name $storageAccountName -VirtualNetworkRule $networkRules.VirtualNetworkRules