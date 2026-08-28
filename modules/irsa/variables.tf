variable "role_name" {
  type        = string
  description = "Name for the IAM role, e.g. \"platform-dev-external-secrets\"."
}

variable "oidc_provider_arn" {
  type        = string
  description = "ARN of the EKS cluster's IAM OIDC provider (from the eks-platform module's oidc_provider_arn output)."
}

variable "oidc_provider_url" {
  type        = string
  description = "OIDC provider URL without the https:// prefix, e.g. \"oidc.eks.us-east-1.amazonaws.com/id/EXAMPLE\" (from the eks-platform module's oidc_provider output)."
}

variable "namespace" {
  type        = string
  description = "Kubernetes namespace the ServiceAccount lives in."
}

variable "service_account_name" {
  type        = string
  description = "Name of the Kubernetes ServiceAccount this role is scoped to. This, combined with namespace, is what makes IRSA least-privilege — only pods using this exact ServiceAccount can assume this role."
}

variable "policy_arns" {
  type        = list(string)
  description = "Managed IAM policy ARNs to attach to the role."
  default     = []
}

variable "inline_policy_json" {
  type        = string
  description = "Optional inline policy document (JSON string) for permissions not covered by a managed policy. Prefer a scoped inline policy over a broad managed policy where one exists — see the eks-platform module's Karpenter controller policy for the pattern."
  default     = null
}

variable "tags" {
  type        = map(string)
  description = "Additional tags applied to the IAM role."
  default     = {}
}