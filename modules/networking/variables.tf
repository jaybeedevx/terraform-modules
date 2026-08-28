variable "environment" {
  type        = string
  description = "Environment name (dev, staging, prod) — used in resource naming and tags."
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be one of: dev, staging, prod."
  }
}

variable "cluster_name" {
  type        = string
  description = "Name of the EKS cluster that will use this VPC — used for Karpenter and ELB subnet discovery tags."
}

variable "vpc_cidr" {
  type        = string
  description = "CIDR block for the VPC, e.g. 10.0.0.0/16."
  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "vpc_cidr must be a valid CIDR block."
  }
}

variable "azs" {
  type        = list(string)
  description = "Availability zones to spread subnets across, e.g. [\"us-east-1a\", \"us-east-1b\", \"us-east-1c\"]."
  validation {
    condition     = length(var.azs) >= 2
    error_message = "At least 2 AZs are required for a production-viable network."
  }
}

variable "single_nat_gateway" {
  type        = bool
  description = "If true, creates one NAT gateway shared across all AZs (cheaper, single point of failure — acceptable for dev/sandbox). If false, creates one NAT per AZ (production-grade redundancy, ~3x NAT cost)."
  default     = false
}

variable "tags" {
  type        = map(string)
  description = "Additional tags applied to all resources in this module."
  default     = {}
}