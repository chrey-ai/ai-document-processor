# CMR Changes

Date: 2026-08-07

## Deployment configuration changes

- Disabled the optional jump-box VM for the active `aidoc0807` azd environment:
  - `AZURE_DEPLOY_VM="false"`
  - `.azure/aidoc0807/config.json`: `deployVM: false`
- Changed the active App Service hosting plan from `Dedicated` to `FlexConsumption` to avoid the subscription's `Total VMs: 0` quota restriction.
- Set the active Function App SKU to `FC1` in `.azure/aidoc0807/config.json`.
- Left network isolation enabled for the active environment.
- The active VM size was set to `Standard_D2as_v5`, but no VM is deployed while `deployVM` is false.

## Cosmos DB compatibility fixes

Updated `infra/modules/db/cosmos.bicep` for the current Cosmos DB API behavior:

- Removed the account-level `enableAnalyticalStorage: true` property. Azure rejected enabling analytical storage during account creation.
- Removed `analyticalStorageTtl` from both SQL containers. Azure rejected that property in the current container creation payload.
- The Bicep template compiled successfully after these changes.

## Deployment troubleshooting

- Identified and canceled the stuck nested deployment `cosmospe`, which was blocked on private endpoint `cosmos-pep-bbh6vryl43tcc` in `Updating` state.
- The canceled nested deployment was not a resource-group or Cosmos account deletion.
- Confirmed that the deployment progressed successfully through:
  - Flex Consumption App Service plan
  - Virtual Network
  - Key Vault
  - Storage accounts
  - Log Analytics workspace
  - Application Insights
  - Function App
  - Cosmos DB
  - Foundry and `gpt-5-mini` model deployment
  - Multiple private endpoints

## Validation

- `az bicep build --file infra/main.bicep --stdout` passed. Existing Bicep linter warnings remain.
- `azd provision --preview --no-prompt` passed after switching to Flex Consumption.
- A subsequent `azd provision --no-prompt` reached the private endpoint reconciliation stage after Cosmos DB succeeded.

## Notes

- `cmr-changes.md` documents the troubleshooting changes made during this session.
- `.vscode/settings.json` was already modified in the worktree and is not included as a change from this session.
- The active `.azure/aidoc0807` environment files are local deployment state and may be ignored by git.

---

Date: 2026-08-18

## Local Functions authentication fixes

Updated `scripts/startLocal.ps1` to support storage accounts that prohibit shared-key authentication:

- Removed the Azure Storage and App Configuration connection-string retrieval and injection logic.
- Removed direct `AzureWebJobsStorage`, `DataStorage`, and `AZURE_APPCONFIG_CONNECTION_STRING` values from the generated `local.settings.json`.
- Removed the deployed managed-identity credential and client ID settings locally while preserving the identity-based storage account names.
- Cleared the deployed `AZURE_CLIENT_ID` from the local process environment.
- Set `AZURE_TOKEN_CREDENTIALS=AzureCliCredential` so local Functions and storage bindings consistently use the signed-in Azure CLI developer identity.
- Applied the credential cleanup for both full starts and quick restarts that use `-SkipSettings`.

## Storage RBAC fixes

Updated `infra/main.bicep` to correct the developer user role assignments:

- Changed the queue assignment from Storage Blob Data Owner to Storage Queue Data Contributor.
- Changed the table assignment from Storage Blob Data Owner to Storage Table Data Contributor.
- Added the missing Storage Queue Data Contributor and Storage Table Data Contributor assignments for the current signed-in user at the active resource-group scope.

## Validation

- Confirmed Azure CLI identity access to the Function host Blob Storage data plane.
- `az bicep build --file infra/main.bicep` passed. Existing unrelated Bicep warnings remain.
- PowerShell and Bicep editor diagnostics reported no errors in the changed files.
- Local Durable Functions initialized its Azure Storage provider and task hub successfully.
- The Functions host indexed all functions and served `start_orchestrator_http` at `http://localhost:7071/api/client`.
- An unauthenticated request without the required payload returned HTTP 400, confirming that the local endpoint was listening and serving requests.

## Pipeline seed data fixes

- Confirmed that the deployed `bronze` and `prompts` containers were empty even though the local pipeline expected seeded assets.
- Uploaded `data/role_library-3.pdf` as `bronze/role_library-3.pdf`.
- Validated `data/prompts.yaml` and uploaded it as `prompts/prompts.yaml`.
- Confirmed both blobs exist at the exact paths consumed by `runDocIntel` and `callAoai`.

## Azure OpenAI version fix

- Identified that `OPENAI_API_VERSION` was incorrectly exported as `2025-08-07`, which is the `gpt-5-mini` model build version rather than an Azure OpenAI REST API version.
- Updated `infra/main.bicep` to keep separate `openaiApiVersion` and `openaiModelVersion` variables.
- Set the API version to `2024-05-01-preview` while retaining model version `2025-08-07`.
- Updated the active azd environment to use `OPENAI_API_VERSION=2024-05-01-preview`.
- Updated `scripts/startLocal.ps1` to remove stale OpenAI environment overrides so local execution reads the canonical values from App Configuration.

## Additional validation

- Confirmed the live AI Services account contains a succeeded `gpt-5-mini` deployment using model version `2025-08-07`.
- Verified the exact Python `AzureOpenAI` client path returned HTTP 200 with API version `2024-05-01-preview`.
- Restarted the local Functions host and confirmed a fresh orchestration passed the previous OpenAI 404 failure point and entered `callAoai` processing.
- Updated `pipeline/pipelineUtils/azure_openai.py` to make the loaded App Configuration map authoritative for the OpenAI endpoint, deployment name, and REST API version, preventing stale terminal environment variables from redirecting SDK requests.
- Verified the Python OpenAI client still used `2024-05-01-preview` and returned HTTP 200 when `OPENAI_API_VERSION=2025-08-07` was deliberately present in the process environment.
- Started the app with direct `func start --build` under that stale environment and confirmed a fresh end-to-end orchestration completed successfully.
