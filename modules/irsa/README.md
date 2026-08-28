# irsa

Generic IRSA (IAM Roles for Service Accounts) module. Creates an IAM role
assumable only by a specific Kubernetes ServiceAccount (namespace + name),
via OIDC federation — the least-privilege mechanism AWS recommends over
instance-profile-wide permissions.

## Usage

\`\`\`hcl
module "external_secrets_irsa" {
  source = "git::https://github.com/jaybeedevx/terraform-modules.git//modules/irsa?ref=irsa/v0.1.0"

  role_name             = "platform-dev-external-secrets"
  oidc_provider_arn     = module.eks_platform.oidc_provider_arn
  oidc_provider_url     = module.eks_platform.oidc_provider
  namespace             = "external-secrets"
  service_account_name  = "external-secrets"
  policy_arns           = ["arn:aws:iam::aws:policy/SecretsManagerReadWrite"]
}
\`\`\`

Then annotate the matching Kubernetes ServiceAccount:

\`\`\`yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: external-secrets
  namespace: external-secrets
  annotations:
    eks.amazonaws.com/role-arn: <module.external_secrets_irsa.role_arn output>
\`\`\`

## Inputs

| Name | Type | Description | Default |
|---|---|---|---|
| role_name | string | IAM role name | required |
| oidc_provider_arn | string | Cluster's OIDC provider ARN | required |
| oidc_provider_url | string | OIDC provider URL (no https://) | required |
| namespace | string | Target Kubernetes namespace | required |
| service_account_name | string | Target ServiceAccount name | required |
| policy_arns | list(string) | Managed policy ARNs to attach | [] |
| inline_policy_json | string | Optional inline policy JSON | null |
| tags | map(string) | Additional role tags | {} |

## Outputs

| Name | Description |
|---|---|
| role_arn | Use as the eks.amazonaws.com/role-arn annotation |
| role_name | IAM role name |

## Design notes

- **Both `sub` and `aud` conditions are required**, not just `sub` — omitting the `aud` check on `sts.amazonaws.com` is a known IRSA misconfiguration that widens who can assume the role beyond what the `sub` condition alone implies. This is a real thing to mention if asked "what's a common IRSA mistake" in an interview.
- **Prefer `inline_policy_json` with a scoped statement over a broad managed policy** wherever a suitably narrow managed policy doesn't already exist — see the eks-platform module's Karpenter controller role for the pattern this module is designed to support.