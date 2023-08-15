#Could make this work for any resource and could also make it able to copy from one resource to another
#future version reduce variables and make it more dynamic


$ResourceGroupName = "rg01"
$SubscriptionName = "sub01"
$Access = @{
    "AD_Group" = @("Logic App Contributor","Website Contributor", "Reader")
}

#Set subscription context
Set-AzContext -SubscriptionName $SubscriptionName

#Get the resource group
$ResourceGroupName = Get-AzResourceGroup -Name $ResourceGroupName

#Assign RBAC permissions to Resource Group
write-host "Assigning RBAC permissions to $ResourceGroupName" -ForegroundColor Green
foreach ($AccessGroup in $Access.GetEnumerator()) {

    #Get the object ID of the group
    $AccessGroup.Name = (Get-AzADGroup -SearchString $AccessGroup.Name)
    $AccessGroup.Value
    foreach ($Role in $AccessGroup.Value) {
        $Role
        New-AzRoleAssignment `
        -ObjectId $AccessGroup.Name.Id `
        -RoleDefinitionName $Role `
        -Scope $ResourceGroupName.ResourceId `
        -ErrorAction Stop
    }
}