###############################################
#         Local Variable definitions          #
###############################################
locals {

  label_tags   = { for key, group in var.worker_group: key => lookup(lookup(group, "settings", {}), "labels", {}) }
  label_taints = { for key, group in var.worker_group: key => lookup(lookup(group, "settings", {}), "taints", {}) }

  kubeconfig_name     = var.kubeconfig_name == "" ? var.cluster_name : var.kubeconfig_name
  kubeconfig_template = var.enable_proxy ? "kubeconfig_proxy.tmpl" : "kubeconfig.tmpl"

  worker_ami = coalesce(join("", data.aws_ami.worker.*.id), var.worker_ami)
  worker_additional_policy_count = var.worker_additional_policy_count == null ? length(var.worker_additional_policy) : var.worker_additional_policy_count

  enable_kiam = var.enable_kiam ? 1 : 0
  enable_flux = lookup(var.flux_config, "enable", lookup(var.flux_default_config, "enable")) ? 1 : 0

  proxy_key_name  = var.proxy_key_name == "" ? lookup(var.worker_group_defaults, "key_name", "") : var.proxy_key_name
  proxy_subnet_id = var.proxy_subnet_id == "" ? element(var.worker_subnet_id, 0) : var.proxy_subnet_id

  ebs_optimized = {
    "c1.medium"    = false
    "c1.xlarge"    = true
    "c3.large"     = false
    "c3.xlarge"    = true
    "c3.2xlarge"   = true
    "c3.4xlarge"   = true
    "c3.8xlarge"   = false
    "c4.large"     = true
    "c4.xlarge"    = true
    "c4.2xlarge"   = true
    "c4.4xlarge"   = true
    "c4.8xlarge"   = true
    "c5.large"     = true
    "c5.xlarge"    = true
    "c5.2xlarge"   = true
    "c5.4xlarge"   = true
    "c5.9xlarge"   = true
    "c5.18xlarge"  = true
    "c5d.large"    = true
    "c5d.xlarge"   = true
    "c5d.2xlarge"  = true
    "c5d.4xlarge"  = true
    "c5d.9xlarge"  = true
    "c5d.18xlarge" = true
    "cc2.8xlarge"  = false
    "cr1.8xlarge"  = false
    "d2.xlarge"    = true
    "d2.2xlarge"   = true
    "d2.4xlarge"   = true
    "d2.8xlarge"   = true
    "f1.2xlarge"   = true
    "f1.4xlarge"   = true
    "f1.16xlarge"  = true
    "g2.2xlarge"   = true
    "g2.8xlarge"   = false
    "g3.4xlarge"   = true
    "g3.8xlarge"   = true
    "g3.16xlarge"  = true
    "h1.2xlarge"   = true
    "h1.4xlarge"   = true
    "h1.8xlarge"   = true
    "h1.16xlarge"  = true
    "hs1.8xlarge"  = false
    "i2.xlarge"    = true
    "i2.2xlarge"   = true
    "i2.4xlarge"   = true
    "i2.8xlarge"   = false
    "i3.large"     = true
    "i3.xlarge"    = true
    "i3.2xlarge"   = true
    "i3.4xlarge"   = true
    "i3.8xlarge"   = true
    "i3.16xlarge"  = true
    "i3.metal"     = true
    "m1.small"     = false
    "m1.medium"    = false
    "m1.large"     = true
    "m1.xlarge"    = true
    "m2.xlarge"    = false
    "m2.2xlarge"   = true
    "m2.4xlarge"   = true
    "m3.medium"    = false
    "m3.large"     = false
    "m3.xlarge"    = true
    "m3.2xlarge"   = true
    "m4.large"     = true
    "m4.xlarge"    = true
    "m4.2xlarge"   = true
    "m4.4xlarge"   = true
    "m4.10xlarge"  = true
    "m4.16xlarge"  = true
    "m5.large"     = true
    "m5.xlarge"    = true
    "m5.2xlarge"   = true
    "m5.4xlarge"   = true
    "m5.9xlarge"   = true
    "m5.18xlarge"  = true
    "m5d.large"    = true
    "m5d.xlarge"   = true
    "m5d.2xlarge"  = true
    "m5d.4xlarge"  = true
    "m5d.12xlarge" = true
    "m5d.24xlarge" = true
    "p2.xlarge"    = true
    "p2.8xlarge"   = true
    "p2.16xlarge"  = true
    "p3.2xlarge"   = true
    "p3.8xlarge"   = true
    "p3.16xlarge"  = true
    "r3.large"     = false
    "r3.xlarge"    = true
    "r3.2xlarge"   = true
    "r3.4xlarge"   = true
    "r3.8xlarge"   = false
    "r4.large"     = true
    "r4.xlarge"    = true
    "r4.2xlarge"   = true
    "r4.4xlarge"   = true
    "r4.8xlarge"   = true
    "r4.16xlarge"  = true
    "t1.micro"     = false
    "t2.nano"      = false
    "t2.micro"     = false
    "t2.small"     = false
    "t2.medium"    = false
    "t2.large"     = false
    "t2.xlarge"    = false
    "t2.2xlarge"   = false
    "t3.nano"      = true
    "t3.micro"     = true
    "t3.small"     = true
    "t3.medium"    = true
    "t3.large"     = true
    "t3.xlarge"    = true
    "t3.2xlarge"   = true
    "x1.16xlarge"  = true
    "x1.32xlarge"  = true
    "x1e.xlarge"   = true
    "x1e.2xlarge"  = true
    "x1e.4xlarge"  = true
    "x1e.8xlarge"  = true
    "x1e.16xlarge" = true
    "x1e.32xlarge" = true
  }

  worker_count = var.worker_count == null ? length(keys(var.worker_group)) : var.worker_count

  worker_group_defaults_defaults = {
    autoscaling_enabled   = false
    desired_capacity      = "1"
    ebs_optimized         = true
    enable_monitoring     = true
    image_id              = local.worker_ami # AMI ID for the eks workers.  If none is provided, use latest version of their EKS optimized AMI.
    instance_type         = "t2.2xlarge"     # Size of the workers instances.
    key_name              = ""
    kubelet_extra_args    = "" # This string is passed directly to kubelet if set. Useful for adding labels or taints.
    max_size              = "3"
    min_size              = "1"
    name                  = "count.index"
    public_ip             = false
    protect_from_scale_in = false
    root_volume_size      = "100"
    root_volume_type      = "gp2"
    root_iops             = "0"
    subnets               = var.worker_subnet_id
    system_profile        = ""
    security_groups       = []
    user_data             = null
    ebs_block_devices     = []
  }

  sg_inbound_default = {
    https = {
      from_port = 443
      protocol  = "TCP"
      source_security_group_id = aws_eks_cluster.this.vpc_config[0].cluster_security_group_id
    }
    kubelet = {
      from_port = 10250
      protocol  = "TCP"
      source_security_group_id = aws_eks_cluster.this.vpc_config[0].cluster_security_group_id
    }
    all = {
      from_port = 0
      protocol  = "-1"
      self      = true
    }
  }

  sg_outbound_default = {
    all = {
      from_port   = 0
      protocol    = "-1"
      cidr_blocks = [ "0.0.0.0/0" ]
    }
  }

  worker_group_defaults = merge(local.worker_group_defaults_defaults, var.worker_group_defaults)

  /* construct list of all subnets used for the node groups */
  worker_group_subnets = distinct(flatten([ for key, settings in var.worker_group:
                                              [ for subnet in lookup(settings, "subnets", local.worker_group_defaults_defaults.subnets): subnet ]
                                          ]))

  /* map worker group AZ to subnet */
  worker_group_az_subnet_tmp = flatten([ for key, settings in var.worker_group: [
                                           for sindex, subnet in lookup(settings, "subnets", local.worker_group_defaults_defaults.subnets):
                                             {
                                               "subnet_id": subnet,
                                               "subnet_index": sindex,
                                               "availability_zone": data.aws_subnet.workers[subnet].availability_zone,
                                               "availability_zone_count": length(lookup(settings, "subnets", local.worker_group_defaults_defaults.subnets)),
                                               "name": lookup(settings, "name", key),
                                               "index": key
                                             }
                                         ]
                                       ])

  worker_group_az_subnet = { for item in local.worker_group_az_subnet_tmp: format("%s-%s", item.name, item.availability_zone) => item }

  enable_iam_service_accounts = (var.cluster_version >= 1.13) ? 1 : 0

  /*
    Default tags (local so you can't over-ride)
  */
  tags = merge(var.tags, { builtWith: "terraform",
                           format("kubernetes.io/cluster/%s", replace(var.cluster_name, ".", "-")): "owned" })
}

/* configure cluster (control plane) */
variable "cluster_name"    {}
variable "cluster_version" {}

variable "cluster_create_timeout" { default = "30m" }
variable "cluster_update_timeout" { default = "60m" }
variable "cluster_delete_timeout" { default = "15m" }

variable "cluster_subnet_id"           { type = list(string) }

/* region specific variables */
variable "eks_cluster_role_arn" { default = null }
variable "eks_worker_role_arn" { default = null }

variable "enabled_cluster_logs" {
  type    = list
  default = null
}

variable "endpoint" {
  type = map
  default = {
    private_access = false
    public_access  = true
  }
}

variable "kubernetes_service_cidr" { default = "172.20.0.0/16" }

/* configure worker nodes */
variable "worker_ami" { default = "" }

variable "worker_additional_policy_count" { default = null }
variable "worker_additional_policy"       { default = [] }

variable "worker_subnet_id"           { type = list(string) }

variable "worker_count" { default = null }
variable "worker_group" {
  type    = any
  default = {}
}

variable "worker_group_defaults" { default = {} }

/* configure kubectl & aws-authenticator */
variable "auth_map_role" { default = [] }

variable "kubeconfig_name"                       { default = "" }
variable "kubeconfig_aws_authenticator_env_vars" { default = {} }

/* configure optional addons */
variable "enable_kiam" { default = false }

variable "flux_config" { default = {} }
variable "flux_default_config" {
  default = {
    enable          = false
    flux_image      = "docker.io/fluxcd/flux:1.14.2"
    helm_image      = "docker.io/fluxcd/helm-operator:0.10.1"
    memcached_image = "memcached:1.5.15"
  }
}

/* configure use of proxy to protect API endpoint */
variable "enable_proxy" { default = false }

variable "proxy_instance_type" { default = "t2.micro" }
variable "proxy_ami"           { default = "ami-032509850cf9ee54e" }

variable "proxy_key_name"  { default = "" }
variable "proxy_subnet_id" { default = "" }

variable "private_subnet_id" { default = [] }
variable "public_subnet_id"  { default = [] }

variable "tags" { default = {} }
