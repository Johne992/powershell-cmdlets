<#
    Created for: Utility
    Created by:  John Lewis
    Created on:  2023-09-14
    Version:     1.0.0
    Purpose:     Dynamically invoke a specified PowerShell script with provided arguments.
                 This utility ensures that the target script exists, logs the start and 
                 completion of the script's execution, and handles any errors that might occur.
    Param:       $ScriptPath - The path to the PowerShell script that needs to be executed.
                 $ScriptArgs - An array of arguments that should be passed to the target script.
                 Example: 
                     -ScriptPath ".\TargetScript.ps1" -ScriptArgs @{Path = "Arg1"; Name = "Arg2"}
#>

param (
    [Parameter(Mandatory=$true)]
    [string]$ScriptPath,

    [Parameter(ValueFromRemainingArguments=$true)]
    [psobject[]]$ScriptArgs
)

# Check if the script exists
if (-not (Test-Path $ScriptPath)) {
    Write-Error "Script $ScriptPath not found!"
    return
}

# Log the start of the script invocation
Write-Output "Starting execution of $ScriptPath..."

try {
    # Invoke the script with the provided arguments
    & $ScriptPath @ScriptArgs

    # Log successful completion
    Write-Output "Successfully executed $ScriptPath."
} catch {
    # Log any errors
    Write-Error "Failed to execute ${ScriptPath}: $_"
}