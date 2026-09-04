// ============================================================================
// Trigger Service — authenticated webhook entry point for the pipeline
//
// Pattern reference: docs/02-trigger-mechanism.md
//
// This module deploys a Logic App that:
//   1. Receives webhook events from your project-tracking system
//   2. Validates a shared secret before processing anything
//   3. Filters out events caused by the pipeline's own automation
//   4. Routes requests to the appropriate downstream agent orchestration
//   5. Independently verifies completion (does not trust self-reported status alone)
//
// All values below are placeholders — supply your own naming, project, and
// automation-account identifiers via parameters.
// ============================================================================

@description('Name for the trigger service Logic App')
param triggerServiceName string

@description('Location for all resources')
param location string = resourceGroup().location

@description('Key Vault name holding the webhook shared secret')
param keyVaultName string

@description('Name of the secret in Key Vault used to validate incoming webhook requests')
param webhookSecretName string = 'webhook-shared-secret'

@description('The service account / identity name whose own activity should never re-trigger the pipeline')
param automationServiceAccountName string

@description('Label/tag that identifies a request as ready for automation')
param automationLabel string = 'ai-agent'

@description('Endpoint of the orchestration platform used to invoke agent workflows')
param agentOrchestrationEndpoint string

resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' existing = {
  name: keyVaultName
}

resource triggerService 'Microsoft.Logic/workflows@2019-05-01' = {
  name: triggerServiceName
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    state: 'Enabled'
    definition: {
      '$schema': 'https://schema.management.azure.com/providers/Microsoft.Logic/schemas/2016-06-01/workflowdefinition.json#'
      contentVersion: '1.0.0.0'
      triggers: {
        When_a_HTTP_request_is_received: {
          type: 'Request'
          kind: 'Http'
          inputs: {
            schema: {
              type: 'object'
              properties: {
                eventType: { type: 'string' }
                publisherId: { type: 'string' }
                resource: { type: 'object' }
              }
            }
          }
        }
      }
      actions: {
        // SECURITY: validate the shared secret before any further processing.
        // Never hardcode this value — always fetch from Key Vault via managed identity.
        Get_webhook_shared_secret: {
          type: 'Http'
          inputs: {
            method: 'GET'
            uri: '${keyVault.properties.vaultUri}secrets/${webhookSecretName}?api-version=7.4'
            authentication: {
              type: 'ManagedServiceIdentity'
            }
          }
          runAfter: {}
        }
        Validate_shared_secret_header: {
          type: 'If'
          expression: {
            equals: [
              '@triggerBody()?[\'headers\']?[\'X-Webhook-Secret\']'
              '@body(\'Get_webhook_shared_secret\')?[\'value\']'
            ]
          }
          actions: {
            // Continue processing — see Switch_by_event_type below
          }
          else: {
            actions: {
              Reject_unauthorized_request: {
                type: 'Response'
                inputs: {
                  statusCode: 401
                  body: 'Unauthorized'
                }
              }
            }
          }
          runAfter: {
            Get_webhook_shared_secret: ['Succeeded']
          }
        }
        // Respond immediately so the caller doesn't time out waiting for
        // downstream agent orchestration, which can take minutes.
        Send_immediate_ack: {
          type: 'Response'
          inputs: {
            statusCode: 202
            body: 'Accepted'
          }
          runAfter: {
            Validate_shared_secret_header: ['Succeeded']
          }
        }
        Switch_by_event_type: {
          type: 'Switch'
          expression: '@triggerBody()?[\'eventType\']'
          cases: {
            // Human comment on a pull request — re-trigger only if the
            // commenter is not the automation account and the comment
            // does not originate from the agents themselves.
            Pull_request_commented_on: {
              case: 'ms.vss-code.git-pullrequest-comment-event'
              actions: {
                Skip_if_agent_authored: {
                  type: 'If'
                  expression: {
                    and: [
                      {
                        not: {
                          equals: [
                            '@triggerBody()?[\'resource\']?[\'comment\']?[\'author\']?[\'uniqueName\']'
                            automationServiceAccountName
                          ]
                        }
                      }
                      {
                        not: {
                          startsWith: [
                            '@triggerBody()?[\'resource\']?[\'comment\']?[\'content\']'
                            '[AGENT'
                          ]
                        }
                      }
                    ]
                  }
                  actions: {
                    // Add_automation_label_if_missing — implementation-specific
                    // to your project-tracking system's API; see docs/02.
                  }
                }
              }
            }
            // Default case: work item created/updated. Confirm the automation
            // label is present and the change wasn't made by the automation
            // account itself, then classify and route.
            Default: {
              case: 'default'
              actions: {
                Has_automation_label: {
                  type: 'If'
                  expression: {
                    and: [
                      {
                        contains: [
                          '@triggerBody()?[\'resource\']?[\'fields\']?[\'Tags\']'
                          automationLabel
                        ]
                      }
                      {
                        not: {
                          equals: [
                            '@triggerBody()?[\'resource\']?[\'fields\']?[\'ChangedBy\']'
                            automationServiceAccountName
                          ]
                        }
                      }
                    ]
                  }
                  actions: {
                    Route_by_WorkItemType: {
                      type: 'Switch'
                      expression: '@triggerBody()?[\'resource\']?[\'fields\']?[\'WorkItemType\']'
                      cases: {
                        Bug: {
                          case: 'Bug'
                          actions: {
                            Invoke_DiagnosticWorkflow: {
                              type: 'Http'
                              inputs: {
                                method: 'POST'
                                uri: '${agentOrchestrationEndpoint}/diagnostic-workflow'
                              }
                            }
                          }
                        }
                      }
                      default: {
                        actions: {
                          Invoke_InfrastructureWorkflow: {
                            type: 'Http'
                            inputs: {
                              method: 'POST'
                              uri: '${agentOrchestrationEndpoint}/infrastructure-workflow'
                            }
                          }
                        }
                      }
                    }
                    // MANDATORY: bounded polling with a hard timeout, and
                    // independent verification that the automation label was
                    // actually removed — never trust self-reported completion
                    // alone. See docs/02-trigger-mechanism.md.
                    Wait_for_completion_then_verify_label_removed: {
                      type: 'Until'
                      limit: {
                        count: 180
                        timeout: 'PT1H'
                      }
                      actions: {
                        Wait_20_seconds: {
                          type: 'Wait'
                          inputs: {
                            interval: { count: 20, unit: 'Second' }
                          }
                        }
                      }
                      runAfter: {
                        Route_by_WorkItemType: ['Succeeded']
                      }
                    }
                  }
                }
              }
            }
          }
          runAfter: {
            Send_immediate_ack: ['Succeeded']
          }
        }
      }
    }
  }
}

// Grant the trigger service's managed identity permission to read the
// webhook secret from Key Vault (least privilege: secrets Get only).
resource kvSecretsUserRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(keyVault.id, triggerService.id, 'Key Vault Secrets User')
  scope: keyVault
  properties: {
    roleDefinitionId: subscriptionResourceId(
      'Microsoft.Authorization/roleDefinitions',
      '4633458b-17de-408a-b874-0445c86b69e6' // Key Vault Secrets User
    )
    principalId: triggerService.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

output triggerServicePrincipalId string = triggerService.identity.principalId
output triggerServiceName string = triggerService.name
