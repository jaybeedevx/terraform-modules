output "role_arn" {
  description = "ARN of the created IAM role — set this as the eks.amazonaws.com/role-arn annotation on the matching Kubernetes ServiceAccount."
  value       = aws_iam_role.this.arn
}

output "role_name" {
  description = "Name of the created IAM role."
  value       = aws_iam_role.this.name
}