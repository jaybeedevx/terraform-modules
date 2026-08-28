run "creates_role_scoped_to_correct_service_account" {
  command = plan

  variables {
    role_name            = "test-external-secrets"
    oidc_provider_arn    = "arn:aws:iam::123456789012:oidc-provider/oidc.eks.us-east-1.amazonaws.com/id/EXAMPLE"
    oidc_provider_url    = "oidc.eks.us-east-1.amazonaws.com/id/EXAMPLE"
    namespace            = "external-secrets"
    service_account_name = "external-secrets"
    policy_arns          = ["arn:aws:iam::aws:policy/SecretsManagerReadWrite"]
  }

  assert {
    condition     = aws_iam_role.this.name == "test-external-secrets"
    error_message = "Role name did not match the input variable."
  }

  assert {
    condition     = length(aws_iam_role_policy_attachment.managed) == 1
    error_message = "Expected exactly 1 managed policy attachment."
  }
}

run "attaches_zero_managed_policies_when_none_given" {
  command = plan

  variables {
    role_name            = "test-no-policies"
    oidc_provider_arn    = "arn:aws:iam::123456789012:oidc-provider/oidc.eks.us-east-1.amazonaws.com/id/EXAMPLE"
    oidc_provider_url    = "oidc.eks.us-east-1.amazonaws.com/id/EXAMPLE"
    namespace            = "default"
    service_account_name = "test-sa"
  }

  assert {
    condition     = length(aws_iam_role_policy_attachment.managed) == 0
    error_message = "Expected no managed policy attachments when policy_arns is empty."
  }

  assert {
    condition     = length(aws_iam_role_policy.inline) == 0
    error_message = "Expected no inline policy resource when inline_policy_json is null."
  }
}

run "creates_inline_policy_when_provided" {
  command = plan

  variables {
    role_name            = "test-inline"
    oidc_provider_arn    = "arn:aws:iam::123456789012:oidc-provider/oidc.eks.us-east-1.amazonaws.com/id/EXAMPLE"
    oidc_provider_url    = "oidc.eks.us-east-1.amazonaws.com/id/EXAMPLE"
    namespace            = "default"
    service_account_name = "test-sa"
    inline_policy_json = jsonencode({
      Version = "2012-10-17"
      Statement = [{
        Effect   = "Allow"
        Action   = ["s3:GetObject"]
        Resource = "*"
      }]
    })
  }

  assert {
    condition     = length(aws_iam_role_policy.inline) == 1
    error_message = "Expected exactly 1 inline policy resource when inline_policy_json is provided."
  }
}