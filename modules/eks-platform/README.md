# eks-platform

Creates a private-endpoint Amazon EKS cluster with a tainted system node group,
Karpenter, and Argo CD. Karpenter receives an IRSA controller role and an EC2
instance profile for provisioned nodes. The module also creates the Karpenter
`NodePool` and `EC2NodeClass` Kubernetes resources.

## Usage

```hcl
module "eks_platform" {
	source = "git::https://github.com/jaybeedevx/terraform-modules.git//modules/eks-platform?ref=eks-platform/v0.1.0"

	cluster_name       = "platform-dev"
	k8s_version        = "1.31"
	vpc_id             = module.networking.vpc_id
	private_subnet_ids = module.networking.private_subnet_ids
	instance_families  = "t3,t3a"
	instance_sizes     = "medium,large"
	max_capacity       = 20
	karpenter_version  = "1.0.6"
	argocd_version      = "7.3.0"
}
```

The AWS, Helm, and Kubernetes providers must be available to the root module.
The Helm and Kubernetes resources use the EKS cluster endpoint and CA data
created by this module, so apply the module from an environment with AWS
credentials and network access to the private cluster endpoint.

## Inputs

| Name | Type | Description | Default |
|---|---|---|---|
| cluster_name | string | EKS cluster name | required |
| k8s_version | string | Supported EKS Kubernetes version, currently `1.27` through `1.39` | required |
| vpc_id | string | VPC ID for the cluster | required |
| private_subnet_ids | list(string) | Private subnets for the cluster and Karpenter nodes | required |
| instance_families | string | Comma-separated Karpenter instance families | required |
| instance_sizes | string | Comma-separated Karpenter instance sizes | required |
| max_capacity | number | Maximum Karpenter capacity, used to derive the NodePool CPU limit | required |
| karpenter_version | string | Pinned Karpenter Helm chart version | required |
| argocd_version | string | Pinned Argo CD Helm chart version | required |
| system_node_instance_type | string | Instance type for the tainted system node group | `t3.small` |
| tags | map(string) | Additional resource tags | `{}` |

## Outputs

| Name | Description |
|---|---|
| cluster_name | EKS cluster name |
| cluster_endpoint | EKS API endpoint |
| cluster_certificate_authority_data | Base64-encoded EKS CA data |
| oidc_provider_arn | EKS OIDC provider ARN for IRSA roles |
| oidc_provider | EKS OIDC provider URL without `https://` |
| cluster_security_group_id | EKS cluster security group ID |
| karpenter_node_role_name | EC2 role name used by Karpenter-provisioned nodes |

## Design notes

- The EKS API endpoint is private-only. Terraform must run from a network that
	can reach the cluster endpoint when managing Helm and Kubernetes resources.
- The system node group is tainted `CriticalAddonsOnly` and sized for CoreDNS
	and the Karpenter controller before Karpenter begins provisioning nodes.
- The root Karpenter `Application` is intentionally managed outside Terraform
	by the cluster bootstrap scripts; this module installs the Argo CD Helm chart
	only.
- `max_capacity` must be greater than zero. The NodePool CPU limit is derived
	from this value as `max_capacity * 4`.

## Testing

Run the module tests with:

```sh
terraform test
```

The tests use a mock Kubernetes provider and validate variable constraints
without requiring AWS credentials or a live cluster.
