variable "cluster_name" {
  type        = string
  description = "EKS cluster name."
}

variable "k8s_version" {
  type        = string
  description = "Kubernetes version, e.g. \"1.31\"."
  validation {
    condition     = can(regex("^1\\.(2[7-9]|3[0-9])$", var.k8s_version))
    error_message = "k8s_version must be a supported EKS version, e.g. 1.31 (adjust the regex as new versions ship)."
  }
}

variable "vpc_id" {
  type        = string
  description = "VPC ID from the networking module."
}

variable "private_subnet_ids" {
  type        = list(string)
  description = "Private subnet IDs from the networking module — used for both the system node group and Karpenter-provisioned nodes."
}

variable "instance_families" {
  type        = string
  description = "Comma-separated instance families Karpenter may choose from, e.g. \"t3,t3a\"."
}

variable "instance_sizes" {
  type        = string
  description = "Comma-separated instance sizes Karpenter may choose from, e.g. \"medium,large\"."
}

variable "max_capacity" {
  type        = number
  description = "Used to derive the Karpenter NodePool CPU limit (max_capacity * 4)."
  validation {
    condition     = var.max_capacity > 0
    error_message = "max_capacity must be greater than 0."
  }
}

variable "karpenter_version" {
  type        = string
  description = "Karpenter Helm chart version — pin explicitly, never track latest."
}

variable "argocd_version" {
  type        = string
  description = "ArgoCD Helm chart version — pin explicitly, never track latest."
}

variable "system_node_instance_type" {
  type        = string
  description = "Instance type for the tainted system node group that hosts CoreDNS and Karpenter itself before Karpenter can provision anything."
  default     = "t3.small"
}

variable "tags" {
  type        = map(string)
  description = "Additional tags applied across cluster resources."
  default     = {}
}