run "creates_expected_subnet_counts" {
  command = plan

  variables {
    environment        = "dev"
    cluster_name       = "test-cluster"
    vpc_cidr           = "10.0.0.0/16"
    azs                = ["us-east-1a", "us-east-1b", "us-east-1c"]
    single_nat_gateway = true
  }

  assert {
    condition     = length(aws_subnet.public) == 3
    error_message = "Expected 3 public subnets, one per AZ."
  }

  assert {
    condition     = length(aws_subnet.private) == 3
    error_message = "Expected 3 private subnets, one per AZ."
  }

  assert {
    condition     = length(aws_nat_gateway.this) == 1
    error_message = "single_nat_gateway=true should create exactly 1 NAT gateway."
  }
}

run "multi_nat_creates_one_per_az" {
  command = plan

  variables {
    environment        = "prod"
    cluster_name       = "test-cluster-prod"
    vpc_cidr           = "10.1.0.0/16"
    azs                = ["us-east-1a", "us-east-1b", "us-east-1c"]
    single_nat_gateway = false
  }

  assert {
    condition     = length(aws_nat_gateway.this) == 3
    error_message = "single_nat_gateway=false should create one NAT per AZ (3)."
  }
}

run "rejects_invalid_cidr" {
  command = plan

  variables {
    environment        = "dev"
    cluster_name       = "test-cluster"
    vpc_cidr           = "not-a-cidr"
    azs                = ["us-east-1a", "us-east-1b"]
    single_nat_gateway = true
  }

  expect_failures = [
    var.vpc_cidr,
  ]
}

run "rejects_single_az" {
  command = plan

  variables {
    environment        = "dev"
    cluster_name       = "test-cluster"
    vpc_cidr           = "10.0.0.0/16"
    azs                = ["us-east-1a"]
    single_nat_gateway = true
  }

  expect_failures = [
    var.azs,
  ]
}