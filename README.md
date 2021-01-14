## Amazon Web Services EKS

[![Build Status](http://jenkins.dat.com/buildStatus/icon?job=DevOps/Terraform/Modules/tf-module-eks/master)](http://jenkins.dat.com/job/DevOps/job/Terraform/job/Modules/job/tf-module-eks/)

A Terraform module to create a managed Kubernetes cluster on AWS EKS.

Official AWS documentation: https://docs.aws.amazon.com/eks/latest/userguide/getting-started.html

## Requirements
- - - -

This module requires:

   -  [Terraform](https://github.com/hashicorp/terraform) `>= 0.13`
   -  [AWS Provider](https://github.com/terraform-providers/terraform-provider-aws) `>= 3.0, < 4.0`
   -  [Template Provider](https://github.com/terraform-providers/terraform-provider-template) `>= 2.1.0`
   -  [Null Resource Provider](https://github.com/terraform-providers/terraform-provider-null) `>= 2.1.0`
   -  [Local Provider](https://github.com/terraform-providers/terraform-provider-local) `>= 1.2.0`

This module is intended to be used with the following [AMI](https://bitbucket.org/dat/packer-coreos-eks/src/master/) based on Fedora CoreOS.

### Inputs
- - - -

This module takes the following inputs:

  Name          | Description   | Type          | Default
  ------------- | ------------- | ------------- | -------------
  `cluster_name` | Name of the EKS cluster. Also used as a prefix in names of related resources. | string | -
  `cluster_version` | Kubernetes version to use for the EKS cluster. | string | -
  `cluster_create_timeout` | Timeout value when creating the EKS cluster. | string | `15m`
  `cluster_delete_timeout` | Timeout value when deleting the EKS cluster. | string | `15m`
  `cluster_update_timeout` | Timeout value when updating the EKS cluster. | string | `60m`
  `cluster_subnet_id` | A list of subnets to place the EKS cluster within. | list | -
  `cluster_security_group_rule` | Additional security group rule(s) to add to EKS cluster control place security group. | list | `[]`
  `endpoint` | Map of boolean for enabling/disabling public and private endpoint access. | map | `{ "private_access" = false, "public_access" = true }`
  `enable_flux` | Enable/disable Weave Flux GitOps operator. | boolean | `false`
  `enable_kiam` | Enable/disable KIAM. | boolean | `false`
  `flux_git_url` | If `enable_kiam` is true, sets the git URL Flux operator points to. | string | ``
  `worker_ami` | Default worker AMI. If not set use Amazon Linux EKS AMI. | string | `""`
  `worker_subnet_id` | A list of subnets to place the EKS worker nodes within. | list | -
  `worker_security_group_rule` | Additional security group rule(s) to add to the EKS worker node security group. | list | `[]`
  `worker_count` | Number of worker autoScaling groups to create (only required if `worker_group` contains interpolated values). | string | `null`
  `worker_group` | List of maps defining worker autoScaling group settings. | list | `[ { "name" = "default" } ]`
  `worker_group_defaults` | Defaults for working autoScaling group settings. | map | `{}`

Both worker_group and worker_group_defaults maps accept the following keys:

  Key          | Description | Type | Default
  ------------ | ----------- | ---- | -------
  `autoscaling_enabled` | Enable cluster autoscaler capability for this worker group. | boolean | `false`
  `desired_capacity`    | Desired worker capacity in the autoscaling group. | string | `1`
  `ebs_optimized`       | Sets whether to use ebs optimization on supported types. | boolean | `true`
  `enable_monitoring`   | Enables/disables detailed monitoring. | boolean | `true`
  `image_id`            | AMI ID for the eks workers. If not specified search for latest version of Amazon EKS optimized AMI. | string | `var.worker_ami if specified`
  `instance_type`       | Size of the worker instance(s). | string | `t2.2xlarge`
  `key_name`            | The key name that should be used for the instances in the autoscaling group. | string | -
  `settings`            | Map of key / value pairs passed in as environment variables via user data. | map | `{}`
  `max_size`            | Maximum worker capacity in the autoscaling group. | string | `3`
  `min_size`            | Minimum worker capacity in the autoscaling group. | string | `1`
  `name`                | Name of the worker group. Literal count.index will never be used but if name is not set, the count.index interpolation will be used. | string | -
  `public_ip`           | Associate a public ip address with a worker. | boolean | `false`
  `protect_from_scale_in` | Prevent AWS from scaling in, so that cluster-autoscaler is solely responsible. | boolean | `false`
  `root_volume_size`    | root volume size of workers instances. | string | `100`
  `root_volume_type`    | root volume type of workers instances, can be 'standard', 'gp2', or 'io1'. | string | `gp2`
  `root_iops`           | The amount of provisioned IOPS. This must be set with a volume_type of 'io1'. | string | `0`
  `subnets`             | A comma delimited string of subnets to place the worker nodes in (ex: subnet-123,subnet-456,subnet-789). | list | `var.worker_subnet_id`


### Ouputs
- - - -

This module exposes the following outputs:

  Name          | Description
  ------------- | -------------
  `cluster_id` | The name/id of the EKS cluster.
  `cluster_endpoint` | The endpoint for your EKS Kubernetes API.
  `cluster_version` | The Kubernetes server version for the EKS cluster.
  `cluster_certificate_authority_data` | Nested attribute containing certificate-authority-data for your cluster. This is the base64 encoded certificate data required to communicate with your cluster.
  `kubeconfig` | kubectl config file for this EKS cluster in YAML format.
  `kubeconfig_json` | kubectl config file for this EKS cluster in JSON format.
  `identity_provider_arn` | ARN assigned by AWS for this OpenID Connect provider.


## Usage
- - - -

Create Kubernetes version 1.11 EKS cluster with 2 autoScaling worker groups.

```hcl

module "eks" {
  source = "git::ssh://git@bitbucket.org/dat/tf-module-eks.git?ref=master"

  cluster_name    = "development"
  cluster_version = "1.11"

  cluster_subnet_id = [ "subnet-5a305f13", "subnet-063f6b61", "subnet-77325d3e", "subnet-b1386cd6" ]
  /* allow access to control plane */
  cluster_security_group_rule = [
    {
      protocol    = "tcp"
      to_port     = 443
      from_port   = 443
      cidr_blocks = [ "0.0.0.0/0" ]
    }
  ]

  worker_subnet_id = [ "subnet-77325d3e", "subnet-b1386cd6" ]

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
      cidr_blocks = [ "0.0.0.0/0" ]
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
