<#
    Created by:  John Lewis
    Created on:  2023-09-07
    Version:     1.0.0
    Purpose:     Update users in Azure Redis Cache
    Rationale:   From short research there isn't a way to bulk add users via the preview on Azure Redis Cache. This script will generate the ARM template 
                 to add the users and then deploy it.
#>

#Set Variables - UPDATE FOR EACH ENVIRONMENT
$SubscriptionName = ""
$ResourceGroup = ""
$ADGroupName = ""
$AzRedisCacheName = ""

#Set subscription context
Set-AzContext -SubscriptionName $SubscriptionName

#Get the AZ AD Group members
$ADGroup = Get-AzADGroup -DisplayName $ADGroupName
$ADGroupMembers = Get-AzADGroupMember -GroupObjectId $ADGroup.Id

#Generate the text
$entries = @()
foreach ($member in $ADGroupMembers) {
    $ObjectId = $member.Id;
    $ObjectIdAlias = $($member.UserPrincipalName).Substring(0, $($member.UserPrincipalName).Length - 11);
    $entry = @"
{
    "type": "Microsoft.Cache/Redis/accessPolicyAssignments",
    "apiVersion": "2023-05-01-preview",
    "name": "[concat(parameters('Redis_${AzRedisCacheName}_name'), '/$ObjectId')]",
    "dependsOn": [
        "[resourceId('Microsoft.Cache/Redis', parameters('Redis_${AzRedisCacheName}_name'))]"
    ],
    "properties": {
        "accessPolicyName": "Data Contributor",
        "objectId": "$ObjectId",
        "objectIdAlias": "$ObjectIdAlias"
    }
}
"@
    $entries += $entry
}

### To Verify entries, output the text to a tile
$outputPath = Join-Path -Path $PSScriptRoot -ChildPath "Deploy-$AzRedisCacheName-$(get-date -Format "yyyy-MM-dd").json"
$entries | Out-File -FilePath $outputPath

#Get the ARM Template for the Azure Redis Cache
$AzRedisCache = Get-AzRedisCache -ResourceGroupName $ResourceGroup -Name $AzRedisCacheName
$ARMTemplate = Export-AzResourceGroup `
    -ResourceGroupName $ResourceGroup `
    -Resource $AzRedisCache.Id `
    -Path $PSScriptRoot `
    -IncludeParameterDefaultValue `
    -IncludeComments `
    -Force

#Get the ARM Template content and convert it to an object
$ARMTemplateContent = Get-Content -Path $ARMTemplate.Path 
$ARMTemplateObj = $ARMTemplateContent | ConvertFrom-Json 

# #Add the entries to the ARM Template
foreach ($entry in $entries) {
    $ARMTemplateObj.resources += $entry | ConvertFrom-Json
}

#Convert the ARM Template object back to JSON and save it
$UpdatedARMTemplateContent = ConvertTo-Json -InputObject $ARMTemplateObj -Depth 100
$UpdatedARMTemplateContent | Out-File -FilePath $ARMTemplate.Path -Force

#Deploy the ARM Template
New-AzResourceGroupDeployment `
    -ResourceGroupName $ResourceGroup `
    -TemplateFile $ARMTemplate.Path `
    -Verbose