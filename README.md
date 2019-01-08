## Amazon Web Services EKS

[![Build Status](http://jenkins.dat.com/buildStatus/icon?job=DevOps/Terraform/Modules/tf-module-eks/master)](http://jenkins.dat.com/job/DevOps/job/Terraform/job/Modules/job/tf-module-eks/)

A Terraform module to create a managed Kubernetes cluster on AWS EKS.

Official AWS documentation: https://docs.aws.amazon.com/eks/latest/userguide/getting-started.html

## Requirements
- - - -

This module requires:

   -  [AWS Provider](https://github.com/terraform-providers/terraform-provider-aws) `>= 1.17.0`
   -  [Template Provider](https://github.com/terraform-providers/terraform-provider-template) `>= 1.0.0`
   -  [Null Resource Provider](https://github.com/terraform-providers/terraform-provider-null) `>= 1.0.0`
   -  [Local Provider](https://github.com/terraform-providers/terraform-provider-local) `>= 1.1.0`

### Inputs
- - - -

This module takes the following inputs:

  Name          | Description   | Type          | Default
  ------------- | ------------- | ------------- | -------------
  cluster_name  | Name of the EKS cluster. Also used as a prefix in names of related resources. | string | -
  cluster_version | Kubernetes version to use for the EKS cluster. | string | -
  cluster_create_timeout | Timeout value when creating the EKS cluster. | string | 15m
  cluster_delete_timeout | Timeout value when deleting the EKS cluster. | string | 15m
  cluster_update_timeout | Timeout value when updating the EKS cluster. | string | 60m
  cluster_subnet_id | A list of subnets to place the EKS cluster within. | list | -
  cluster_role_arn | IAM role ARN to use for the EKS cluster control plane. | string | -
  cluster_security_group_rule | Additional security group rule(s) to add to EKS cluster control place security group. | list | []
  worker_ami | Default worker AMI. If not set use Amazon Linux EKS AMI. | string | ""
  worker_role_arn | IAM role ARN to use for the EKS worker nodes. | string | -
  worker_instance_profile | IAM instance profile to use for EKS worker nodes. | string | -
  worker_subnet_id | A list of subnets to place the EKS worker nodes within. | list | -
  worker_security_group_rule | Additional security group rule(s) to add to the EKS worker node security group. | list | []
  worker_count | Number of worker autoScaling groups to create. | string | 1
  worker_group | List of maps defining worker autoScaling group settings. | list | [ { "name" = "default" } ]
  worker_group_defaults | Defaults for working autoScaling group settings. | map | {}

### Ouputs
- - - -

This module exposes the following outputs:

  Name          | Description
  ------------- | -------------
  cluster_id | The name/id of the EKS cluster.
  cluster_endpoint | The endpoint for your EKS Kubernetes API.
  cluster_version | The Kubernetes server version for the EKS cluster.
  cluster_certificate_authority_data | Nested attribute containing certificate-authority-data for your cluster. This is the base64 encoded certificate data required to communicate with your cluster.
  kubeconfig | kubectl config file contents for this EKS cluster.


## Usage
- - - -

Create Kubernetes version 1.11 EKS cluster with 2 autoScaling worker groups.

```hcl

module "eks" {
  source = "git::ssh://git@bitbucket.org/dat/tf-module-eks.git?ref=master"

  cluster_name    = "development"
  cluster_version = "1.11"

  cluster_role_arn = "INSTANCE_ROLE_ARN"

  cluster_subnet_id = [ "subnet-5a305f13", "subnet-063f6b61", "subnet-77325d3e", "subnet-b1386cd6" ]
  /* allow access to control plane */
  cluster_security_group_rule = [
    {
      protocol    = "tcp"
      to_port     = 443
      from_port   = 443
      cidr_blocks = "0.0.0.0/0"
    }
  ]

  worker_subnet_id = [ "subnet-77325d3e", "subnet-b1386cd6" ]

  worker_instance_profile = "INSTANCE_PROFILE_NAME"
  worker_role_arn         = "INSTANCE_ROLE_ARN"

  /* set defaults for worker groups */
  worker_group_defaults {
    key_name = "development_operations"
  }

  /* allow SSH access to worker nodes */
  worker_security_group_rule = [
    {
      protocol    = "tcp"
      to_port     = 22
      from_port   = 22
      cidr_blocks = "0.0.0.0/0"
    }
  ]

  /* create our worker autoScalingGroups */
  worker_count = 2
  worker_group = [
    {
      name                = "group1"
      max_size            = 6
      desired_capacity    = 4
      autoscaling_enabled = true
    },
    {
      name              = "group2"
      enable_monitoring = false
      root_volume_size  = 200
      rool_volume_type  = "io"
      root_iops         = "2000"
    }
  ]
}

```
