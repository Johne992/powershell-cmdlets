# Creator: John Lewis
# Creation Date: 2024-01-26
# Purpose: Deploy Architecture
# Task: CATTSK0795671

Import-module "C:\Users\e51473a\Documents\code\WorkRepos\Infrastructure-Modules\AzureUtilities.psm1"

$SubscriptionName = "SIRT-AlertPolicy"
$ResourceGroupName = "SIRT-AlertPolicy"
$ARMTemplate = "Deployment-AlertPolicyARM.json"
$TemplateParameters = ""

Set-AzureContext -SubscriptionName $SubscriptionName

if ($TemplateParameters -eq "") {
    New-AzResourceGroupDeployment `
        -ResourceGroupName $ResourceGroupName `
        -TemplateFile $ARMTemplate
}
else {
    New-AzResourceGroupDeployment `
        -ResourceGroupName $ResourceGroupName `
        -TemplateFile $ARMTemplate `
        -TemplateParameterObject $templateParameters
}