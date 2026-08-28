# networking

Multi-AZ VPC with public/private subnets, EKS/ELB auto-discovery tags,
and Karpenter subnet discovery tags pre-applied.

## Usage

\`\`\`hcl
module "networking" {
  source = "git::https://github.com/jaybeedevx/terraform-modules.git//modules/networking?ref=networking/v0.1.0"

  environment        = "dev"
  cluster_name       = "platform-dev"
  vpc_cidr           = "10.0.0.0/16"
  azs                = ["us-east-1a", "us-east-1b", "us-east-1c"]
  single_nat_gateway = true  # dev: cost over redundancy
}
\`\`\`

## Inputs

| Name | Type | Description | Default |
|---|---|---|---|
| environment | string | dev / staging / prod | required |
| cluster_name | string | Used in tags for EKS/Karpenter discovery | required |
| vpc_cidr | string | VPC CIDR block | required |
| azs | list(string) | Availability zones, minimum 2 | required |
| single_nat_gateway | bool | Single shared NAT vs. one per AZ | false |
| tags | map(string) | Additional resource tags | {} |

## Outputs

| Name | Description |
|---|---|
| vpc_id | ID of the created VPC |
| public_subnet_ids | Public subnet IDs |
| private_subnet_ids | Private subnet IDs |
| nat_gateway_ids | NAT gateway ID(s) |

## Design notes

- **NAT trade-off:** `single_nat_gateway = true` is a deliberate cost-over-redundancy choice — a single NAT is a single point of failure for all private-subnet egress. Use `false` for any environment where an AZ outage taking down all outbound traffic is unacceptable.
- **Karpenter tag:** private subnets are tagged `karpenter.sh/discovery = <cluster_name>` so the `eks-platform` module's `EC2NodeClass` can select them without hardcoded subnet IDs.