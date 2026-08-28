# Plan-mode tests limited to what's verifiable without real AWS state —
# see the testing note at the top of this file for why full coverage
# isn't possible at this module's level.

mock_provider "kubernetes" {}

run "rejects_unsupported_k8s_version" {
  command = plan

  variables {
    cluster_name       = "test-cluster"
    k8s_version        = "1.19" # too old, should fail validation
    vpc_id             = "vpc-00000000000000000"
    private_subnet_ids = ["subnet-00000000000000001", "subnet-00000000000000002"]
    instance_families  = "t3"
    instance_sizes     = "medium"
    max_capacity       = 10
    karpenter_version  = "1.0.6"
    argocd_version     = "7.3.0"
  }

  expect_failures = [
    var.k8s_version,
  ]
}

run "rejects_zero_max_capacity" {
  command = plan

  variables {
    cluster_name       = "test-cluster"
    k8s_version        = "1.31"
    vpc_id             = "vpc-00000000000000000"
    private_subnet_ids = ["subnet-00000000000000001", "subnet-00000000000000002"]
    instance_families  = "t3"
    instance_sizes     = "medium"
    max_capacity       = 0
    karpenter_version  = "1.0.6"
    argocd_version     = "7.3.0"
  }

  expect_failures = [
    var.max_capacity,
  ]
}