output "cluster_name" {
  description = "EKS cluster name."
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "EKS cluster API endpoint."
  value       = module.eks.cluster_endpoint
}

output "cluster_certificate_authority_data" {
  description = "Base64-encoded cluster CA certificate."
  value       = module.eks.cluster_certificate_authority_data
  sensitive   = true
}

output "oidc_provider_arn" {
  description = "Cluster's OIDC provider ARN — pass to irsa module calls for LBC, ExternalSecrets, and workload roles at the environment level."
  value       = module.eks.oidc_provider_arn
}

output "oidc_provider" {
  description = "Cluster's OIDC provider URL (no https:// prefix) — pass to irsa module calls."
  value       = module.eks.oidc_provider
}

output "cluster_security_group_id" {
  description = "Cluster security group ID."
  value       = module.eks.cluster_security_group_id
}

output "karpenter_node_role_name" {
  description = "IAM role name EC2 instances use — needed if any other module needs to reference or extend node permissions."
  value       = aws_iam_role.karpenter_node.name
}