# This repo is a BICEP Microsoft IaC language for infra deployment in modules that:

- Fully integrated Function App + Logic App deployment.

- Managed Identity + RBAC for secure internal api calls.

- Key Vault-based secret injection for production-grade safety.

- One-click (or one-pipeline) deployment to any environment.

- code comments included


# FUNCTION APP
Function apps, particularly in the context of Azure Functions, are serverless computing solutions that allow developers to run code in response to events without managing infrastructure.

Function apps serve as a hosting container for one or more Azure Functions. They group related functions together under a unified management structure, making it easier to deploy, manage, and scale applications. Each function within a function app is designed to perform a specific task, triggered by various events such as HTTP requests, timers, or messages from queues.
They scale automatically base on demand and triggered by various events (Event-Driven), such as file uploads, database changes, or scheduled tasks, enabling the creation of responsive applications.

# Some Use Cases of Function App:
- Automation & Scheduled Tasks
- Data Processing
- API & Backend Services
- Event-Driven Workflows
- AI & Machine Learning
- Custom Business Logic
- Integration & Orchestration


# LOGIC APP
Azure Logic Apps is a cloud platform where you can create and run automated workflows in, across, and outside the software ecosystems in your enterprise or organization. This platform greatly reduces or removes the need to write code when your workflows must connect and work with resources from different components, such as services, systems, apps, and data sources.

# Some Use Cases of Logic App:
- Schedule and send email notifications using Office 365 when a specific event happens, for example, a new file is uploaded.
- Route and process customer orders across on-premises systems and cloud services.
- Move uploaded files from an SFTP or FTP server to Azure Blob Storage.
- Monitor social media activity, analyze the sentiment, and create alerts or tasks for items that need review.

# How they can work together

- You can use a Logic App to orchestrate a high-level workflow that calls an Azure Function for a specific, custom task that the connectors can't handle directly. 

- For example, a Logic App might trigger when a new file is uploaded, then use a Function to perform a complex image processing operation before continuing the workflow.

- SUMMARY: Azure Logic Apps are for visual, low-code workflow automation and integration, while Azure Functions are for event-driven, code-based execution


# Preparing Key Vault Secrets
- Before you deploy, you need to store the storage connection string inside the Key Vault manually (or via pipeline), command used:

# Generate the connection string from your storage account

CONN=$(az storage account show-connection-string \
  -n stintdev001 \
  -g rg-integration-dev \
  --query connectionString -o tsv)

# Store it as a secret in Key Vault
az keyvault secret set \
  --vault-name kv-integration-dev \
  --name StorageConnection \
  --value "$CONN"


# Project Tree

integration-devops/
├── bicep/
│   ├── main.bicep
│   ├── modules/
│   │   ├── functionapp.bicep
│   │   └── logicapp.bicep
├── logicapps/
│   └── order-sync.json
└── functionapp/
    ├── HttpTrigger1/
    │   ├── index.js
    │   └── package.json



# Deliverable:

- A deployable Logic App definition file (order-sync.json).
When a new order file arrives in an Azure Blob Storage container, the Logic App reads it, sends the data to Dynamics 365 Finance through an HTTP connector, and logs the result in Azure Table Storage.

- A Bicep module correctly referencing it via loadTextContent().

- Parameters ready for secure and environment-specific injection.


# Create a Service Principal (bash)

az ad sp create-for-rbac \
  --name integration-sp \
  --role contributor \
  --scopes /subscriptions/<SUBSCRIPTION_ID> \
  --sdk-auth

In Azure DevOps, create a Service Connection (type = Azure Resource Manager → Service principal (auto)).


# Validate and Deploy Locally (bash)
Before automation, test your deployment manually:

az login
az group create -n rg-integration-dev -l westeurope
az deployment group create \
  --resource-group rg-integration-dev \
  --template-file ./bicep/main.bicep \
  --parameters environment=dev



# Unit Test (PowerShell Pester)
tests/test_functionapp.ps1, this test should be 200 which means status code OK

Describe "Function App API Health" {
    It "Function should respond with 200" {
        $response = Invoke-WebRequest -Uri "http://localhost:7071/api/HttpTrigger1" -UseBasicParsing
        $response.StatusCode | Should -Be 200
    }
}


# Deploy Integration Stack (Logic App + Function App)

# Pipeline Integration (GitHub Actions)
