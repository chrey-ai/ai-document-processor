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
