// ============================================================================
// Main orchestration — deploys the trigger service and identity model
// described in docs/02-trigger-mechanism.md and docs/08-security-design.md.
//
// This deploys the infrastructure-level scaffolding only. The agents
// themselves (enrichment, authoring, independent audit, drift detection)
// are configured on your agent orchestration platform of choice using the
// instruction templates in /agents.
// ============================================================================

@description('Location for all resources')
param location string = resourceGroup().location

@description('Base name used to derive resource names, e.g. "a2a-iac-security"')
param baseName string

@description('Key Vault name holding the webhook shared secret')
param keyVaultName string

@description('The service account / identity name whose own activity should never re-trigger the pipeline')
param automationServiceAccountName string

@description('Endpoint of the orchestration platform used to invoke agent workflows')
param agentOrchestrationEndpoint string

@description('Display name for the Entra application securing agent tool access')
param toolsAppDisplayName string = '${baseName}-tools-api'

var toolsAppUniqueName = '${toLower(baseName)}-tools-${uniqueString(resourceGroup().id)}'

module identity 'modules/identity.bicep' = {
  name: 'identity-deployment'
  params: {
    appDisplayName: toolsAppDisplayName
    appUniqueName: toolsAppUniqueName
  }
}

module triggerService 'modules/trigger-service.bicep' = {
  name: 'trigger-service-deployment'
  params: {
    triggerServiceName: '${baseName}-trigger'
    location: location
    keyVaultName: keyVaultName
    automationServiceAccountName: automationServiceAccountName
    agentOrchestrationEndpoint: agentOrchestrationEndpoint
  }
}

output toolsAppClientId string = identity.outputs.appClientId
output toolsAppIdentifierUri string = identity.outputs.appIdentifierUri
output triggerServiceName string = triggerService.outputs.triggerServiceName
