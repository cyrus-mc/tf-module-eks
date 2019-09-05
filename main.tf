data "aws_caller_identity" "current" {}

/* query AmazonEKS AMI for specific EKS version */
data "aws_ami" "worker" {
  /* only query if we didn't supply our own AMI */
  count = var.worker_ami == "" ? 1 : 0

  filter {
    name   = "name"
    values = [ "amazon-eks-node-${var.cluster_version}-*" ]
  }

  most_recent = true
  owners      = [ "602401143452" ]
}

data "aws_subnet" "selected" {
  id = var.cluster_subnet_id[0]
}

/* create worker security group */
resource "aws_security_group" "worker" {
  name_prefix = format("EKS_worker.%s-", var.cluster_name)

  vpc_id = data.aws_subnet.selected.vpc_id

  tags = merge(var.tags, { format("kubernetes.io/cluster/%s", var.cluster_name) = "owned"
                           "Name" = format("EKS_worker.%s", var.cluster_name) })
}

resource "aws_security_group_rule" "worker_egress" {
  security_group_id = aws_security_group.worker.id

  cidr_blocks = [ "0.0.0.0/0" ]
  protocol    = "-1"
  from_port   = 0
  to_port     = 0
  type        = "egress"
}

resource "aws_security_group_rule" "workers_self" {
  security_group_id = aws_security_group.worker.id

  source_security_group_id = aws_security_group.worker.id
  protocol                 = "-1"
  from_port                = 0
  to_port                  = 65535
  type                     = "ingress"
}

resource "aws_security_group_rule" "worker_cluster" {
  security_group_id = aws_security_group.worker.id

  source_security_group_id = aws_security_group.cluster.id
  protocol                 = "all"
  from_port                = 0
  to_port                  = 65535
  type                     = "ingress"
}

resource "aws_security_group_rule" "worker_cluster_https" {
  security_group_id = aws_security_group.worker.id

  source_security_group_id = aws_security_group.cluster.id
  protocol                 = "tcp"
  from_port                = 443
  to_port                  = 443
  type                     = "ingress"
}

resource "aws_security_group_rule" "worker_supplied" {
  count = length(var.worker_security_group_rule)

  security_group_id = aws_security_group.worker.id

  cidr_blocks = var.worker_security_group_rule[ count.index ][ "cidr_blocks" ]
  protocol    = var.worker_security_group_rule[ count.index ][ "protocol" ]
  from_port   = var.worker_security_group_rule[ count.index ][ "from_port" ]
  to_port     = var.worker_security_group_rule[ count.index ][ "to_port" ]
  type        = "ingress"
}

/* create control plane security group */
resource "aws_security_group" "cluster" {
  name_prefix = format("EKS_control.%s-", var.cluster_name)

  vpc_id = data.aws_subnet.selected.vpc_id

  tags = merge(var.tags, { format("kubernetes.io/cluster/%s", var.cluster_name) = "owned"
                           "Name" = format("EKS_control.%s", var.cluster_name) })
}

resource "aws_security_group_rule" "cluster_egress" {
  security_group_id = aws_security_group.cluster.id

  cidr_blocks = [ "0.0.0.0/0" ]
  protocol    = "-1"
  from_port   = 0
  to_port     = 0
  type        = "egress"
}

resource "aws_security_group_rule" "cluster_worker_ingress" {
  security_group_id = aws_security_group.cluster.id

  source_security_group_id = aws_security_group.worker.id
  protocol                 = "TCP"
  from_port                = 443
  to_port                  = 443
  type                     = "ingress"
}

resource "aws_security_group_rule" "cluster_supplied" {
  count = length(var.cluster_security_group_rule)

  security_group_id = aws_security_group.worker.id

  cidr_blocks = var.cluster_security_group_rule[ count.index ][ "cidr_blocks" ]
  protocol    = var.cluster_security_group_rule[ count.index ][ "protocol" ]
  from_port   = var.cluster_security_group_rule[ count.index ][ "from_port" ]
  to_port     = var.cluster_security_group_rule[ count.index ][ "to_port" ]
  type        = "ingress"
}

/* create cluster IAM role */
data "aws_iam_policy_document" "cluster_assume_role_policy" {
  statement {
    sid = "EKSClusterAssumeRole"

    actions = [
      "sts:AssumeRole",
    ]

    principals {
      type        = "Service"
      identifiers = [ "eks.amazonaws.com" ]
    }
  }
}

resource "aws_iam_role" "cluster" {
  name = format("EKS_control.%s", var.cluster_name)

  assume_role_policy    = data.aws_iam_policy_document.cluster_assume_role_policy.json
  force_detach_policies = true
}

resource "aws_iam_role_policy_attachment" "cluster_AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.cluster.name
}

resource "aws_iam_role_policy_attachment" "cluster_AmazonEKSServicePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSServicePolicy"
  role       = aws_iam_role.cluster.name
}

/* create worker IAM role */
data "aws_iam_policy_document" "worker_assume_role_policy" {
  statement {
    sid = "EKSWorkerAssumeRole"

    actions = [
      "sts:AssumeRole",
    ]

    principals {
      type        = "Service"
      identifiers = [ "ec2.amazonaws.com" ]
    }
  }
}

resource "aws_iam_role" "worker" {
  name = format("EKS_worker.%s", var.cluster_name)

  assume_role_policy    = data.aws_iam_policy_document.worker_assume_role_policy.json
  force_detach_policies = true
}

resource "aws_iam_role_policy_attachment" "worker_AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.worker.name
}

resource "aws_iam_role_policy_attachment" "worker_AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.worker.name
}

resource "aws_iam_role_policy_attachment" "worker_AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.worker.name
}

resource "aws_iam_role_policy_attachment" "worker_existing" {
  count = length(var.worker_additional_policy)

  policy_arn = format("arn:aws:iam::aws:policy/%s", element(var.worker_additional_policy, count.index))
  role       = aws_iam_role.worker.name
}

resource "aws_iam_instance_profile" "worker" {
  name = format("EKS_worker.%s", var.cluster_name)

  role = aws_iam_role.worker.name
}

/* support for kiam */
resource "aws_iam_role" "kiam" {
  count = local.enable_kiam

  name = format("EKS_kiam.%s", var.cluster_name)

  assume_role_policy    = templatefile("${path.module}/templates/kiam/assume_role_policy.tmpl",
                                       { role = aws_iam_role.worker.arn })
  force_detach_policies = true
}

resource "aws_iam_policy" "kiam" {
  count = local.enable_kiam

  name = format("EKS_kiam.%s", var.cluster_name)

  path = "/"
  policy = templatefile("${path.module}/templates/kiam/server_policy.tmpl", {})
}

resource "aws_iam_role_policy_attachment" "kiam" {
  count = local.enable_kiam

  policy_arn = aws_iam_policy.kiam[0].arn
  role       = aws_iam_role.kiam[0].name
}

resource "aws_iam_policy" "kiam_worker" {
  count = local.enable_kiam

  name = format("EKS_kiam-worker.%s", var.cluster_name)

  path = "/"
  policy = templatefile("${path.module}/templates/kiam/worker_policy.tmpl",
                        { role = aws_iam_role.kiam[0].arn })
}

resource "aws_iam_role_policy_attachment" "kiam_worker" {
  count = local.enable_kiam

  policy_arn = aws_iam_policy.kiam_worker[0].arn
  role       = aws_iam_role.worker.name
}

resource "aws_eks_cluster" "this" {
  /* name of the cluster */
  name = replace(var.cluster_name, ".", "-")

  /* desired Kubernetes master version */
  version = var.cluster_version

  //role_arn = "${var.cluster_role_arn}"
  role_arn = aws_iam_role.cluster.arn

  enabled_cluster_log_types = var.enabled_cluster_logs

  timeouts {
    create = var.cluster_create_timeout
    update = var.cluster_update_timeout
    delete = var.cluster_delete_timeout
  }

  /* list all subnets that belong to cluster (private and public) */
  vpc_config {
    security_group_ids = [ aws_security_group.cluster.id ]
    subnet_ids         = var.cluster_subnet_id
  }

  lifecycle {
    /* ignore cluster version as upgrades will be done out of band */
    ignore_changes = [
      version
    ]
  }

  /* set implicit dependency */
  depends_on = [
    aws_iam_role_policy_attachment.cluster_AmazonEKSClusterPolicy,
    aws_iam_role_policy_attachment.cluster_AmazonEKSServicePolicy,
  ]
}

/* create worker autoscaling groups */
resource "null_resource" "tags_as_list_of_maps" {
  count = length(keys(var.tags))

  triggers = {
    key                 = element(keys(var.tags), count.index)
    value               = element(values(var.tags), count.index)
    propagate_at_launch = true
  }
}

data "template_file" "worker_userdata" {
  count = local.worker_count

  template = file("${path.module}/templates/userdata.sh.tpl")

  vars = {
    cluster_name        = aws_eks_cluster.this.name
    endpoint            = aws_eks_cluster.this.endpoint
    cluster_auth_base64 = aws_eks_cluster.this.certificate_authority[0].data
    system_profile      = lookup(var.worker_group[ count.index ], "system_profile",
                                                                  local.worker_group_defaults[ "system_profile" ])
    kubelet_extra_args  = lookup(var.worker_group[ count.index ], "kubelet_extra_args",
                                                                  local.worker_group_defaults[ "kubelet_extra_args" ])
  }
}

resource "aws_launch_configuration" "worker" {
  count = local.worker_count

  name_prefix = format("EKS_%s-%s-", var.cluster_name,
                                     lookup(var.worker_group[ count.index ], "name", count.index))

  enable_monitoring = lookup(var.worker_group[ count.index ], "enable_monitoring",
                                                              local.worker_group_defaults[ "enable_monitoring" ])

  associate_public_ip_address = lookup(var.worker_group[count.index], "public_ip",
                                                                      local.worker_group_defaults[ "public_ip" ])

  security_groups = [ aws_security_group.worker.id ]

  iam_instance_profile = aws_iam_instance_profile.worker.id
  image_id = lookup(var.worker_group[ count.index ], "image_id",
                                                     local.worker_group_defaults[ "image_id" ])

  instance_type = lookup(var.worker_group[ count.index ], "instance_type",
                                                          local.worker_group_defaults[ "instance_type" ])

  key_name = lookup(var.worker_group[ count.index ], "key_name",
                                                     local.worker_group_defaults[ "key_name" ])

  user_data_base64 = base64encode(element(data.template_file.worker_userdata.*.rendered, count.index))

  /* only enable ebs optimized for instance types that allow it */
  ebs_optimized = lookup(var.worker_group[count.index], "ebs_optimized",
                                                        lookup(local.ebs_optimized, lookup(var.worker_group[ count.index ], "instance_type",
                                                        local.worker_group_defaults[ "instance_type" ]),
                                                        false))

  root_block_device {
    volume_size = lookup(var.worker_group[ count.index ], "root_volume_size",
                                                          local.worker_group_defaults[ "root_volume_size" ])
    volume_type = lookup(var.worker_group[ count.index ], "root_volume_type",
                                                          local.worker_group_defaults[ "root_volume_type" ])
    iops        = lookup(var.worker_group[ count.index ], "root_iops", local.worker_group_defaults[ "root_iops" ])

    delete_on_termination = true
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "worker" {
  count = local.worker_count

  name_prefix = format("EKS_%s-%s-", var.cluster_name,
                                     lookup(var.worker_group[ count.index ], "name", count.index))

  launch_configuration = element(aws_launch_configuration.worker.*.id, count.index)

  desired_capacity = lookup(var.worker_group[ count.index ], "desired_capacity",
                                                             local.worker_group_defaults[ "desired_capacity" ])
  max_size         = lookup(var.worker_group[ count.index ], "max_size",
                                                             local.worker_group_defaults[ "max_size" ])
  min_size         = lookup(var.worker_group[ count.index ], "min_size",
                                                             local.worker_group_defaults[ "min_size" ])

  protect_from_scale_in = lookup(var.worker_group[ count.index ], "protect_from_scale_in",
                                                                  local.worker_group_defaults["protect_from_scale_in"])

  /* network settings */
  vpc_zone_identifier = split(",", coalesce(lookup(var.worker_group[count.index], "subnets", ""),
                                            local.worker_group_defaults["subnets"]))

  lifecycle {
    ignore_changes = [ desired_capacity ]
  }

  tags = concat([ { "key"                 = "Name"
                    "value"               = format("%s-%s", aws_eks_cluster.this.name,
                                                             lookup(var.worker_group[ count.index ], "name", count.index))
                    "propagate_at_launch" = true },
                  { "key"                 = "kubernetes.io/cluster/${aws_eks_cluster.this.name}"
                    "value"               = "owned"
                    "propagate_at_launch" = true },
                  { "key" = "k8s.io/cluster-autoscaler/${lookup(var.worker_group[ count.index ], "autoscaling_enabled",
                                                                                          local.worker_group_defaults[ "autoscaling_enabled" ]) ? "enabled" : "disabled"}"
                    "value"               = "true"
                    "propagate_at_launch" = true
                   } ], local.asg_tags)
}

/* configure worker authentication */
data "template_file" "worker_aws_auth" {
  template = file("${path.module}/templates/config-map-aws-auth.json.tmpl")

  vars = {
    worker_role_arn = aws_iam_role.worker.arn
    map_roles       = join(",", data.template_file.role_aws_auth.*.rendered)
  }
}

/* map roles */
data "template_file" "role_aws_auth" {
  count = length(var.auth_map_role)

  template = file("${path.module}/templates/config-map-aws-auth-map_roles.json.tmpl")

  vars = {
    role     = var.auth_map_role[ count.index ][ "role" ]
    username = var.auth_map_role[ count.index ][ "username" ]
    group    = var.auth_map_role[ count.index ][ "group" ]
    account  = data.aws_caller_identity.current.account_id
  }
}

/* configure kubectl */
data "template_file" "aws_authenticator_env_vars" {
  count = length(var.kubeconfig_aws_authenticator_env_vars)

  template = <<EOF
        - name: $${key}
          value: $${value}
EOF


  vars = {
    key   = element(keys(var.kubeconfig_aws_authenticator_env_vars), count.index)
    value = element(values(var.kubeconfig_aws_authenticator_env_vars), count.index)
  }
}

data "template_file" "kubeconfig" {
  template = file("${path.module}/templates/${local.kubeconfig_template}")

  vars = {
    cluster_name                    = aws_eks_cluster.this.name
    kubeconfig_name                 = local.kubeconfig_name
    endpoint                        = var.enable_proxy ? join("", aws_instance.proxy.*.private_ip) : aws_eks_cluster.this.endpoint
    cluster_auth_base64             = aws_eks_cluster.this.certificate_authority[0].data
    aws_authenticator_env_variables = length(var.kubeconfig_aws_authenticator_env_vars) > 0 ? "      env:\n${join("\n", data.template_file.aws_authenticator_env_vars.*.rendered)}" : ""
  }
}

data "template_file" "aws_authenticator_env_vars_json" {
  count = length(var.kubeconfig_aws_authenticator_env_vars)

  template = <<EOF
            {
              "name": "$${key}",
              "value": "$${value}"
            }
EOF


  vars = {
    key   = element(keys(var.kubeconfig_aws_authenticator_env_vars), count.index)
    value = element(values(var.kubeconfig_aws_authenticator_env_vars), count.index)
  }
}

data "template_file" "kubeconfig_json" {
  template = file("${path.module}/templates/${local.kubeconfig_template}.json")

  vars = {
    cluster_name                    = aws_eks_cluster.this.name
    kubeconfig_name                 = local.kubeconfig_name
    endpoint                        = var.enable_proxy ? join("", aws_instance.proxy.*.private_ip) : aws_eks_cluster.this.endpoint
    cluster_auth_base64             = aws_eks_cluster.this.certificate_authority[0].data
    aws_authenticator_env_variables = join(",", data.template_file.aws_authenticator_env_vars_json.*.rendered)
  }
}

resource "null_resource" "update_worker_aws_auth" {
  provisioner "local-exec" {
    command = "${path.module}/kubectl_apply.sh '${data.template_file.kubeconfig_json.rendered}' '${data.template_file.worker_aws_auth.rendered}'"
  }

  triggers = {
    config_map_rendered = data.template_file.worker_aws_auth.rendered
  }

  /* only run after the cluster is up */
  depends_on = [
    aws_eks_cluster.this
  ]
}

/* install flux */
data "template_file" "flux_deployment" {
  count = local.enable_flux

  template = file("${path.module}/templates/flux/deployment.json.tmpl")

  vars = {
    git_url = var.flux_git_url
  }
}

resource "null_resource" "apply_flux_deployment" {
  count = local.enable_flux

  provisioner "local-exec" {
    command = "${path.module}/kubectl_apply.sh '${data.template_file.kubeconfig_json.rendered}' '${data.template_file.flux_deployment[0].rendered}'"
  }

  triggers = {
    deployment_rendered = data.template_file.flux_deployment[0].rendered
  }

  /* only run after the cluster is up */
  depends_on = [
    aws_eks_cluster.this
  ]
}
