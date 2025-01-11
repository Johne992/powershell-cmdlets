<#
    Created by:  John Lewis
    Created on:  2024-10-11
    Version:     2.1.0
    Dependencies:  Azure-Utilities.psm1
#>

Import-Module ".\AzureUtilities.psm1" -Force


#------ Pre Deployment ------

# Set subscription context
$env = ""
$entraEnv = ""
$projectName = ""
$cleanProjName = ($projectName -replace '\s', '').ToLower()
$deploymentName = "${cleanProjName}-${entraEnv}-Environment"
$SubscriptionName = " ${entraEnv} 1"
write-host "Set context to subscription where new deployment will be created" -ForegroundColor Green
Set-AzureContext -SubscriptionName $SubscriptionName
$CurrentUser = Get-AzContext | Select-Object -ExpandProperty Account

write-host "Context set, Updating Parameters"

# Resource Parameters
$updatedParams = @{
    "location"              = "centralus"
    "environment"           = $env
    "projectName"           = $cleanProjName
    "createdBy"             = $CurrentUser.Id
    "tagValues"             = @{

    }
    "instanceNumber"        = "01"
    "roleAssignments"       = @{} # generated and updated below
    # Generate Directory Objects
    "directoryObjects"      = @(
        @{  "name"   = ""
            "id"     = Get-ObjectId("")
            "roles"  = @('')
            "scopes" = @('')
        }
    )  
}

$updatedParams

write-host "Generated Directory Objects"
$directoryObjects

$roleDefinitions = @{
    'Reader'                                    = (Get-AzRoleDefinition -Name 'Reader').Id
}
write-host "Generated Role Defintions"
$roleDefinitions


$roleToScope = @{
    'Reader'                                    = @("resourceGroup")
}


# Preprocess Role Assignments
$i = 0
$cleanedAssignments = @()
foreach ($principal in $updatedParams.directoryObjects) {
    write-host "--Directory Object--"
    $principal
    foreach ($role in $principal.roles) {
        write-host "--Role--"
        $role
        if ($roleToScope[$role]) {
            foreach ($scope in $roleToScope[$role]) {
                write-host "--Scope--"
                $scope
                if (-not $roleDefinitions.ContainsKey($role)) {
                    Write-Warning "Role $role is not defined in roleDefinitions."
                    continue
                }

                $cleanedAssignments += @{
                    principalId      = $principal.Id
                    role             = $role
                    roleDefinitionId = $roleDefinitions[$role]
                    scope            = $scope
                }
                $cleanedAssignments[$i]
                $i++
            }
        }
        else {
            Write-Warning "Role $role is not found in roleToScope."
        }
    }
}

Write-Host "Cleaned Assignments"


# Organize Role Assignments by Unique Scopes
$organizedRoleAssignments = @{}
$uniqueScopes = $roleToScope.Values | ForEach-Object { $_ } | Sort-Object -Unique
foreach ($scope in $uniqueScopes) {
    $assignmentsForScope = $cleanedAssignments | Where-Object { $_.scope -eq $scope }
    $organizedRoleAssignments[$scope] = @($assignmentsForScope)
}

$jsonOutput = $organizedRoleAssignments | ConvertTo-JSON -Depth 10 -Compress
$jsonOutput | Out-File -FilePath "roleAssignments.json" -Encoding 'UTF8' -Force
Write-Host "Role Assignments (JSON) file created"

$updatedParams.roleAssignments = $organizedRoleAssignments



#------ Parameters ------

#Delete the main.parameters.JSON file if it exists
if (Test-Path 'main.parameters.JSON') {
    Remove-Item 'main.parameters.JSON'
}

#Build main.bicepparm into a JSON parameters file
az bicep build-params --file main.bicepparam --outfile main.parameters.JSON

#Get the parameters object from the JSON file
$JSONFile = Get-Content 'main.parameters.JSON' | ConvertFrom-Json
$params = $JSONFile.parameters

#Iterate over the hash table and update the value field of each parameter in $params
foreach ($key in $updatedParams.Keys) {
    if ($params.$key) {
        $params.$key.value = $updatedParams.$key
    }
    else {
        Write-Host "Parameter $key not found in the parameters file."
    }
}

#Replace JSONFile.parameters with the updated $params
$JSONFile.parameters = $params

#Update the JSON File
$JSONFile | ConvertTo-Json -Depth 10 | Set-Content 'main.parameters.JSON'

#Delete the main.parameters.bicepparam file if it exists
if (Test-Path 'main.parameters.bicepparam') {
    Remove-Item 'main.parameters.bicepparam'
}

#Decompile the JSON File back into main.bicepparam
az bicep decompile-params --file main.parameters.JSON --bicep-file 'main.bicep'

#Change first line of main.parameters.bicepparam to 'using 'main.bicep''
$firstLine = "using 'main.bicep'"
(Get-Content 'main.parameters.bicepparam') | ForEach-Object {
    if ($_.StartsWith("using '/main.bicep'")) {
        $_ = $firstLine # Replace the line
    }
    $_
} | Set-Content 'main.parameters.bicepparam'

#----- Deployment -----
Exit
# Deploy main.bicep using the newly made .bicepparam file
New-AzDeployment `
    -Name $deploymentName `
    -Location $updatedParams.location `
    -TemplateFile "main.bicep" `
    -TemplateParameterFile "main.parameters.bicepparam" `
    -Verbose


#----- Post Deployment -----

Write-Host "Environment setup completed."
