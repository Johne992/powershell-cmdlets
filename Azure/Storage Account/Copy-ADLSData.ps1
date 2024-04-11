<#
.SYNOPSIS
This script copies data from one Azure Data Lake Storage (ADLS) account to another using AzCopy.

.DESCRIPTION
The script uses AzCopy, a command-line utility, to copy data between two ADLS accounts. It copies data from multiple directories in the source account to a single directory in the destination account. The directories to copy from are specified in the $sourceBlobDirectories array.

.NOTES
AzCopy must be installed and added to your system's PATH environment variable to run this script.

.AUTHOR
John Lewis

.DATE
2024-04-11
#>

# Set the source and destination storage account details
$sourceStorageAccountName = "<source-storage-account-name>"
$sourceContainerName = "<source-container-name>"
$sourceSubdirectory = "<source-subdirectory-path>"
$sourceBlobDirectories = @("<source-blob-directory-1>", "<source-blob-directory-2>", "<source-blob-directory-n>")

$destinationStorageAccountName = "<destination-storage-account-name>"
$destinationContainerName = "<destination-container-name>"
$destinationSubdirectory = "<destination-subdirectory-path>"

Invoke-Expression -Command "azcopy login"

foreach ($blobDirectory in $sourceBlobDirectories) {
    # Construct the source and destination URLs
    $sourceUrl = "https://$sourceStorageAccountName.blob.core.windows.net/$sourceContainerName$sourceSubdirectory/$blobDirectory/UC1/*"
    $destinationUrl = "https://$destinationStorageAccountName.blob.core.windows.net/$destinationContainerName$destinationSubdirectory"

    # Construct the AzCopy command
    $azCopyCommand = "azcopy copy '$sourceUrl' '$destinationUrl'"
    # --recursive=true

    # Start a new job to run the AzCopy command
    Start-Job -ScriptBlock { param($command) Invoke-Expression -Command $command } -ArgumentList $azCopyCommand
}

# Wait for all jobs to complete
Get-Job | Wait-Job

# Display the results of the jobs
Get-Job | Receive-Job

# Clean up the jobs
Get-Job | Remove-Job