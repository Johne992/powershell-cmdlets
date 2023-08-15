---

# Azure Resource Deployment Plan

## Overview

This document outlines the resources to be deployed on Azure, their associated resource groups, IAM access, and Azure AD objects associated with the deployment within a specific subscription.

---

## Subscription: `[SubscriptionName]`

### Resource Group: `[ResourceGroupName]`

#### **Azure Resources**:

##### **Resource**: Azure Data Factory
  - **Type**: Data Factory
  - **Description**: Data integration and ETL service.
  - **IAM Access**:
    - **Role**: Key Vault Accessor
    - **Assigned To**: Azure Data Factory
    - **Scope**: Key Vault

##### **Resource**: Azure Databricks
  - **Type**: Databricks
  - **Description**: Apache Spark-based analytics platform.
  - **IAM Access**:
    - **Role**: Key Vault Accessor
    - **Assigned To**: Azure Databricks
    - **Scope**: Key Vault

##### **Resource**: Azure Key Vault
  - **Type**: Key Vault
  - **Description**: Secrets and keys management.
  - **Stored Secrets**: Databricks App Registrations Secrets

#### **Azure AD Objects**:

##### **Object**: Databricks App Registration (Read)
  - **Type**: App Registration
  - **Description**: App registration for Databricks read access.
  - **Secrets Location**: Azure Key Vault

##### **Object**: Databricks App Registration (Write)
  - **Type**: App Registration
  - **Description**: App registration for Databricks write access.
  - **Secrets Location**: Azure Key Vault

##### **Object**: Databricks App Registration (SCIM Provisioning)
  - **Type**: App Registration
  - **Description**: App registration for Databricks SCIM provisioning.
  - **Secrets Location**: Azure Key Vault
  - **Azure AD Groups Being Provisioned**: 
    - `[GroupName1]`
    - `[GroupName2]`
    - `[...and so on]`

---

### Azure Storage Account Modifications: `[StorageAccountName]`

#### **New Containers & Sub-directories**:

##### **Container**: `[NewContainerName1]`
  - **Description**: Description of the container's purpose.
  - **ACL Modifications**: 
    - `[ACL Modification Details]`

##### **Subdirectory**: `[NewSubdirectoryName1]` in `[NewContainerName1]`
  - **Description**: Description of the subdirectory's purpose.
  - **ACL Modifications**: 
    - `[ACL Modification Details]`

#### **Existing Containers & Sub-directories**:

##### **Container**: `[ExistingContainerName1]`
  - **Description**: Description of the container's purpose.
  - **ACL Modifications**: 
    - `[ACL Modification Details]`

##### **Subdirectory**: `[ExistingSubdirectoryName1]` in `[ExistingContainerName1]`
  - **Description**: Description of the subdirectory's purpose.
  - **ACL Modifications**: 
    - `[ACL Modification Details]`

#### **IAM Modifications for Storage Account**:

  - **Role**: `[RoleName]`
  - **Assigned To**: `[EntityName]`
  - **Scope**: `[ScopeDetails]`

---

## Additional Notes

- Ensure that the secrets for the Databricks App Registrations are stored securely in the Azure Key Vault.
- Ensure that the necessary permissions are granted to Azure Data Factory and Azure Databricks to access the Key Vault.

---

## Approval

**Prepared By**: `[Your Name]`  
**Date**: `[Preparation Date]`

**Approved By**: `[Approver's Name]`  
**Date**: `[Approval Date]`

---

Replace the placeholders (e.g., `[SubscriptionName]`, `[ResourceGroupName]`, etc.) with the appropriate details for your specific deployment. Adjust the template as needed based on the complexity and requirements of your deployment.