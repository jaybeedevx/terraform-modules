# --------------------------
# EKS CLUSTER (Private Endpoint Only)
# --------------------------
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = var.cluster_name
  cluster_version = var.k8s_version

  cluster_endpoint_public_access  = false
  cluster_endpoint_private_access = true

  enable_irsa = true

  vpc_id     = var.vpc_id
  subnet_ids = var.private_subnet_ids

  eks_managed_node_groups = {
    system = {
      instance_types = [var.system_node_instance_type]
      min_size       = 2
      max_size       = 3
      desired_size   = 2

      taints = {
        critical_addons = {
          key    = "CriticalAddonsOnly"
          value  = "true"
          effect = "NO_SCHEDULE"
        }
      }

      labels = {
        role = "system"
      }
    }
  }

  cluster_addons = {
    coredns = {
      most_recent = true
      configuration_values = jsonencode({
        tolerations = [{
          key      = "CriticalAddonsOnly"
          operator = "Equal"
          value    = "true"
          effect   = "NoSchedule"
        }]
      })
    }
    kube-proxy = { most_recent = true }
    vpc-cni    = { most_recent = true }
  }

  tags = var.tags
}

# --------------------------
# KARPENTER CONTROLLER ROLE — via the irsa module, not hand-rolled
# --------------------------
module "karpenter_irsa" {
  source = "../irsa"

  role_name            = "${var.cluster_name}-karpenter-controller"
  oidc_provider_arn    = module.eks.oidc_provider_arn
  oidc_provider_url    = module.eks.oidc_provider
  namespace            = "karpenter"
  service_account_name = "karpenter"
  tags                 = var.tags

  inline_policy_json = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowScopedEC2InstanceActions"
        Effect = "Allow"
        Action = [
          "ec2:RunInstances", "ec2:CreateFleet", "ec2:CreateLaunchTemplate",
          "ec2:DeleteLaunchTemplate", "ec2:CreateTags", "ec2:TerminateInstances"
        ]
        Resource = "*"
        Condition = {
          StringEquals = { "aws:RequestTag/karpenter.sh/discovery" = var.cluster_name }
        }
      },
      {
        Sid      = "AllowScopedEC2InstanceActionsWithNoTags"
        Effect   = "Allow"
        Action   = ["ec2:RunInstances", "ec2:CreateFleet", "ec2:CreateLaunchTemplate"]
        Resource = ["arn:aws:ec2:*:*:subnet/*", "arn:aws:ec2:*:*:security-group/*"]
      },
      {
        Sid    = "AllowReadActions"
        Effect = "Allow"
        Action = [
          "ec2:DescribeInstances", "ec2:DescribeLaunchTemplates", "ec2:DescribeSecurityGroups",
          "ec2:DescribeSubnets", "ec2:DescribeInstanceTypes", "ec2:DescribeInstanceTypeOfferings",
          "ec2:DescribeAvailabilityZones", "ec2:DescribeSpotPriceHistory", "ec2:DescribeImages",
          "pricing:GetProducts", "ssm:GetParameter"
        ]
        Resource = "*"
      },
      {
        Sid      = "AllowPassingInstanceRole"
        Effect   = "Allow"
        Action   = "iam:PassRole"
        Resource = aws_iam_role.karpenter_node.arn
      },
      {
        Sid      = "AllowScopedInstanceProfileReads"
        Effect   = "Allow"
        Action   = "iam:GetInstanceProfile"
        Resource = aws_iam_instance_profile.karpenter_node.arn
      },
      {
        Sid      = "AllowInterruptionQueueActions"
        Effect   = "Allow"
        Action   = ["sqs:DeleteMessage", "sqs:GetQueueUrl", "sqs:ReceiveMessage"]
        Resource = aws_sqs_queue.karpenter_interruption.arn
      },
      {
        Sid      = "AllowAPIServerEndpointDiscovery"
        Effect   = "Allow"
        Action   = "eks:DescribeCluster"
        Resource = module.eks.cluster_arn
      }
    ]
  })
}

resource "aws_sqs_queue" "karpenter_interruption" {
  name                      = "${var.cluster_name}-karpenter-queue"
  message_retention_seconds = 300
}

# --------------------------
# KARPENTER NODE ROLE — stays hand-rolled: this is an EC2 instance role
# (trusts ec2.amazonaws.com), not an OIDC-federated role, so it's not a
# fit for the irsa module, which is specifically for ServiceAccount-scoped
# roles assumed via web identity federation.
# --------------------------
resource "aws_iam_role" "karpenter_node" {
  name = "${var.cluster_name}-karpenter-node"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

resource "aws_iam_instance_profile" "karpenter_node" {
  name = "${var.cluster_name}-karpenter-node-profile"
  role = aws_iam_role.karpenter_node.name
}

resource "aws_iam_role_policy_attachment" "karpenter_node_policies" {
  for_each = {
    AmazonEKSWorkerNodePolicy          = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
    AmazonEKS_CNI_Policy               = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
    AmazonEC2ContainerRegistryReadOnly = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
    AmazonSSMManagedInstanceCore       = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  }
  policy_arn = each.value
  role       = aws_iam_role.karpenter_node.name
}

# --------------------------
# KARPENTER HELM INSTALL
# --------------------------
provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
    }
  }
}

resource "helm_release" "karpenter" {
  name             = "karpenter"
  namespace        = "karpenter"
  create_namespace = true
  repository       = "oci://public.ecr.aws/karpenter"
  chart            = "karpenter"
  version          = var.karpenter_version

  values = [
    yamlencode({
      settings = {
        clusterName           = var.cluster_name
        clusterEndpoint       = module.eks.cluster_endpoint
        interruptionQueueName = aws_sqs_queue.karpenter_interruption.name
      }
      serviceAccount = {
        annotations = {
          "eks.amazonaws.com/role-arn" = module.karpenter_irsa.role_arn
        }
      }
      tolerations = [{
        key      = "CriticalAddonsOnly"
        operator = "Equal"
        value    = "true"
        effect   = "NoSchedule"
      }]
    })
  ]

  depends_on = [module.eks]
}

resource "kubernetes_manifest" "karpenter_nodepool" {
  depends_on = [helm_release.karpenter]
  manifest = yamldecode(templatefile("${path.module}/templates/karpenter_nodepool.yaml.tpl", {
    instance_families = var.instance_families
    instance_sizes    = var.instance_sizes
    max_cpu           = var.max_capacity * 4
  }))
}

resource "kubernetes_manifest" "karpenter_ec2nodeclass" {
  depends_on = [helm_release.karpenter]
  manifest = yamldecode(templatefile("${path.module}/templates/karpenter_ec2nodeclass.yaml.tpl", {
    cluster_name     = var.cluster_name
    instance_profile = aws_iam_instance_profile.karpenter_node.name
  }))
}

# --------------------------
# ARGOCD — Helm release only. The root Application is applied separately
# by cluster-bootstrap/scripts/apply-root-app.sh, outside Terraform state.
# --------------------------
resource "helm_release" "argocd" {
  name             = "argocd"
  namespace        = "argocd"
  create_namespace = true
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = var.argocd_version

  values = [
    yamlencode({
      configs = { cm = { "timeout.reconciliation" = "180s" } }
      server  = { service = { type = "ClusterIP" } }
    })
  ]

  depends_on = [module.eks]
}