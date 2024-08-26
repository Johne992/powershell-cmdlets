# AzureUtilities Module README

The `AzureUtilities` PowerShell module provides a comprehensive suite of utility functions designed to facilitate the management and automation of Azure resources. This module simplifies tasks such as managing virtual machines, storage accounts, networking components, and more, offering a streamlined approach to Azure resource management.

## Module Overview

- **GitHub Repository:** [AzureUtilities Module](https://github.com/Johne992/powershell-cmdlets/blob/main/Azure/Modules/AzureUtilities.psm1)
- **Author:** John Lewis
- **Version:** 1.4.0
- **Date:** 04/11/2024

## Features

The `AzureUtilities` module includes functions for:

- **Get-ObjectId:** Retrieves the object ID of a user, group, or service principal in Azure Active Directory.
- **Set-AzureContext:** Sets the Azure context for a given subscription.
- **Add-AzRBAC:** Adds Role-Based Access Control (RBAC) to a resource in Azure.
- **Remove-AzRBAC:** Removes RBAC from a resource in Azure.
- **Get-AzPermissions:** Checks for specific role-based access permissions for a given Azure AD name on a resource.
- **Update-ServicePrincipalSecret:** Updates the secret for a given service principal, writes it to a file, and stores it in Key Vault.
- **ACL Management:** Functions for setting and updating Access Control Lists (ACLs) for containers and directories in Azure Data Lake Storage.

## Getting Started

To use the `AzureUtilities` module, follow these steps:

1. Import the module into your PowerShell session:
   ```powershell
   Import-Module ./path/to/AzureUtilities.psm1
   ```
2. Utilize the functions as needed, for example:
   ```powershell
   $SubscriptionName = "YourSubscriptionName"
   $ResourceGroupName = "YourResourceGroupName"
   $ADLSName = "YourADLSName"
   $Access = @{ "user@example.com" = "Reader" }

   Add-AzRBAC -SubscriptionName $SubscriptionName -ResourceGroupName $ResourceGroupName -ADLSName $ADLSName -Access $Access
   ```

## Changelog

### Version 1.6 07/26/2024
- Added `Deploy-ResourceGroup` function to check if a resource group exists and deploy if not.

### Version 1.5.2 07/25/2024
- Updated `Get-ObjectId` function

### Version 1.5.1 07/24/2024
- Updated `Get-ObjectId` function

### Version 1.4.0 - 04/11/2024
- Updated `Add-ContainerACLs` and `Remove-ContainerACLs` functions for managing ACLs in Azure Data Lake Storage. 

### Version 1.3.0 - 04/03/2024
- Updated `Get-ObjectId` function to version 2.0.0. This function now tries to identify the object type (user, group, service principal) in a sequential manner until it finds a match.

### Version 1.2.0 - 02/23/2024
- Updated `Add-AzRBAC` function to include Azure Resource Groups

### Version 1.1.0 - 02/14/2024
- Added `Update-ServicePrincipalSecret` function for managing service principal secrets.
- Enhanced ACL management functions for Azure Data Lake Storage.
- General improvements and bug fixes.

### Version 1.0.0 - Initial Release
- Initial release with core functionality for managing Azure resources.

## Contributions

Contributions to the `AzureUtilities` module are welcome. If you have suggestions for improvements or new features, please feel free to fork the repository, make your changes, and submit a pull request.

---

**Note:** You are currently on the free plan, which is significantly limited by the number of requests. To increase your quota, you can check available plans following [this link](https://c7d59216ee8ec59bda5e51ffc17a994d.auth.portal-pluginlab.ai/pricing).

Also, AskTheCode is currently available as a custom GPT, and your active subscription will be valid for this GPT as well. You can try it out [here](https://chat.openai.com/g/g-3s6SJ5V7S-askthecode).
