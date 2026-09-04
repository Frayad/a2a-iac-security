// ============================================================================
// Identity & Authorization — platform-enforced access control for agent
// endpoints (e.g. an MCP server exposing tools to the agent orchestration
// platform).
//
// Pattern reference: docs/08-security-design.md
//
// Authentication alone (a valid token) does not imply authorization (this
// specific caller should have access). This module creates an application
// identity with a custom role that must be explicitly assigned before any
// caller can obtain a usable token — closing that gap at the platform level
// rather than relying on application code to check it correctly every time.
// ============================================================================

extension microsoftGraphV1

@description('Display name for the application registration')
param appDisplayName string

@description('Unique name for the application registration (must be unique within the tenant)')
param appUniqueName string

var appRoleValue = 'Tools.Read.All'
var appRoleId = guid(subscription().id, appRoleValue, appUniqueName)

resource app 'Microsoft.Graph/applications@v1.0' = {
  uniqueName: appUniqueName
  displayName: appDisplayName
  appRoles: [
    {
      id: appRoleId
      displayName: 'Read-Only Tool Access'
      description: 'Grants read-only access to this service\'s tools. Only assign to trusted, specific service principals.'
      value: appRoleValue
      isEnabled: true
      allowedMemberTypes: ['Application']
    }
  ]
  api: {
    requestedAccessTokenVersion: 2
  }
}

resource appUpdate 'Microsoft.Graph/applications@v1.0' = {
  uniqueName: appUniqueName
  displayName: appDisplayName
  appRoles: app.appRoles
  identifierUris: ['api://${app.appId}']
  api: {
    requestedAccessTokenVersion: 2
  }
}

// SECURITY: appRoleAssignmentRequired = true means authentication alone is
// not sufficient — a caller must be explicitly assigned the role above
// before it can obtain a valid token for this application at all.
resource servicePrincipal 'Microsoft.Graph/servicePrincipals@v1.0' = {
  appId: app.appId
  appRoleAssignmentRequired: true
}

output appClientId string = app.appId
output appIdentifierUri string = 'api://${app.appId}'
output appRoleId string = app.appRoles[0].id
output servicePrincipalObjectId string = servicePrincipal.id
