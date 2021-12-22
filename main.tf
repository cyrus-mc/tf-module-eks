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

/* query details for all subnets used for node groups */
data "aws_subnet" "workers" {
  for_each = toset(local.worker_group_subnets)

  id = each.value
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
  count = var.eks_cluster_role_arn != null ? 0 : 1

  name = format("EKS_control.%s", var.cluster_name)

  assume_role_policy    = data.aws_iam_policy_document.cluster_assume_role_policy.json
  force_detach_policies = true

  tags = merge(var.tags, local.tags)
}

resource "aws_iam_role_policy_attachment" "cluster_AmazonEKSClusterPolicy" {
  count = var.eks_cluster_role_arn != null ? 0 : 1

  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.cluster[count.index].name
}

resource "aws_iam_role_policy_attachment" "cluster_AmazonEKSServicePolicy" {
  count = var.eks_cluster_role_arn != null ? 0 : 1

  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSServicePolicy"
  role       = aws_iam_role.cluster[count.index].name
}

/* create worker IAM role */
data "aws_iam_policy_document" "worker_assume_role_policy" {
  count = var.eks_cluster_role_arn != null ? 0 : 1

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
  count = var.eks_worker_role_arn != null ? 0 : 1

  name = format("EKS_worker.%s", var.cluster_name)

  assume_role_policy    = data.aws_iam_policy_document.worker_assume_role_policy[0].json
  force_detach_policies = true

  tags = merge(var.tags, local.tags)
}

resource "aws_iam_role_policy_attachment" "worker_AmazonEKSWorkerNodePolicy" {
  count = var.eks_worker_role_arn != null ? 0 : 1

  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.worker[0].name
}

resource "aws_iam_role_policy_attachment" "worker_AmazonEKS_CNI_Policy" {
  count = var.eks_worker_role_arn != null ? 0 : 1

  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.worker[0].name
}

resource "aws_iam_role_policy_attachment" "worker_AmazonEC2ContainerRegistryReadOnly" {
  count = var.eks_worker_role_arn != null ? 0 : 1

  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"

  role       = aws_iam_role.worker[0].name
}

resource "aws_iam_role_policy_attachment" "worker_existing" {
  count = local.worker_additional_policy_count

  policy_arn = length(split(":", var.worker_additional_policy[ count.index ])) > 1 ? var.worker_additional_policy[ count.index ] : format("arn:aws:iam::aws:policy/%s", var.worker_additional_policy[ count.index ])
  role       = aws_iam_role.worker[count.index].name
}

resource "aws_iam_instance_profile" "worker" {
  count = var.eks_worker_role_arn != null ? 0 : 1

  name = format("EKS_worker.%s", var.cluster_name)

  # role = var.eks_worker_role_arn != null ? format("EKS_worker.%s", var.cluster_name) : aws_iam_role.worker[0].name
  role = aws_iam_role.worker[0].name

  tags = merge(var.tags, local.tags)
}

/* support for kiam */
resource "aws_iam_role" "kiam" {
  count = local.enable_kiam

  name = format("EKS_kiam.%s", var.cluster_name)

  assume_role_policy    = templatefile("${path.module}/templates/kiam/assume_role_policy.tmpl",
                                       { role = aws_iam_role.worker[0].arn })
  force_detach_policies = true

  tags = merge(var.tags, local.tags)
}

resource "aws_iam_policy" "kiam" {
  count = local.enable_kiam

  name = format("EKS_kiam.%s", var.cluster_name)

  path = "/"
  policy = templatefile("${path.module}/templates/kiam/server_policy.tmpl", {})

  tags = merge(var.tags, local.tags)
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

  tags = merge(var.tags, local.tags)
}

resource "aws_iam_role_policy_attachment" "kiam_worker" {
  count = local.enable_kiam

  policy_arn = aws_iam_policy.kiam_worker[0].arn
  role       = aws_iam_role.worker[0].name
}

resource "aws_eks_cluster" "this" {
  /* name of the cluster */
  name = replace(var.cluster_name, ".", "-")

  /* desired Kubernetes master version */
  version = var.cluster_version

  role_arn = var.eks_cluster_role_arn != null ? var.eks_cluster_role_arn : aws_iam_role.cluster[0].arn
  //role_arn = aws_iam_role.cluster.arn

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

    endpoint_private_access = var.endpoint.private_access
    endpoint_public_access  = var.endpoint.public_access
  }

  lifecycle {
    /* ignore cluster version as upgrades will be done out of band */
    ignore_changes = [
      version
    ]
  }

  tags = merge(var.tags, local.tags)

  /* set implicit dependency */
  depends_on = [
    aws_iam_role_policy_attachment.cluster_AmazonEKSClusterPolicy,
    aws_iam_role_policy_attachment.cluster_AmazonEKSServicePolicy,
  ]
}

/* https://docs.aws.amazon.com/eks/latest/userguide/sec-group-reqs.html */

/* create node security group */
resource "aws_security_group" "cluster" {
  name_prefix = format("EKS_control.%s-", var.cluster_name)

  vpc_id = data.aws_subnet.selected.vpc_id

  tags = merge(var.tags, { "Name" = format("eks-additional-sg-%s", var.cluster_name) })
}

/* use _rule resource as k8s will add rules based on ingress resources */
resource "aws_security_group_rule" "cluster-egress" {
  for_each = local.sg_outbound_default

  type = "egress"

  from_port                = each.value.from_port
  to_port                  = lookup(each.value, "to_port", each.value.from_port)
  protocol                 = lookup(each.value, "protocol", "TCP")
  cidr_blocks              = lookup(each.value, "cidr_blocks", null)
  source_security_group_id = lookup(each.value, "cidr_blocks", null) == null ? lookup(each.value, "source_security_group_id", null) : null
  self                     = lookup(each.value, "cidr_blocks", null) == null ? (lookup(each.value, "security_groups", null) == null ? lookup(each.value, "self", null) : null) : null

  security_group_id = aws_security_group.cluster.id
}

resource "aws_security_group_rule" "cluster-ingress" {
  for_each = local.sg_inbound_default

  type = "ingress"

  from_port                = each.value.from_port
  to_port                  = lookup(each.value, "to_port", each.value.from_port)
  protocol                 = lookup(each.value, "protocol", "TCP")
  cidr_blocks              = lookup(each.value, "cidr_blocks", null)
  source_security_group_id = lookup(each.value, "cidr_blocks", null) == null ? lookup(each.value, "source_security_group_id", null) : null
  self                     = lookup(each.value, "cidr_blocks", null) == null ? (lookup(each.value, "security_groups", null) == null ? lookup(each.value, "self", null) : null) : null

  security_group_id = aws_security_group.cluster.id
}

resource "aws_launch_configuration" "worker" {
  for_each = var.worker_group

  name_prefix = format("EKS_%s-%s-", var.cluster_name,
                                     lookup(each.value, "name", each.key))

  enable_monitoring = lookup(each.value, "enable_monitoring", local.worker_group_defaults[ "enable_monitoring" ])

  associate_public_ip_address = lookup(each.value, "public_ip", local.worker_group_defaults[ "public_ip" ])

  security_groups = concat([ aws_security_group.cluster.id ],
                           lookup(each.value, "security_groups", local.worker_group_defaults[ "security_groups" ]))

  iam_instance_profile = format("EKS_worker.%s", var.cluster_name)

  image_id      = lookup(each.value, "image_id", local.worker_group_defaults[ "image_id" ])
  instance_type = lookup(each.value, "instance_type", local.worker_group_defaults[ "instance_type" ])

  key_name = lookup(each.value, "key_name", local.worker_group_defaults[ "key_name" ])

  user_data = lookup(each.value, "user_data", local.worker_group_defaults[ "user_data" ])

  /* only enable ebs optimized for instance types that allow it */
  ebs_optimized = lookup(each.value, "ebs_optimized", lookup(local.ebs_optimized, lookup(each.value, "instance_type",
                                                                                                     local.worker_group_defaults[ "instance_type" ]),
                                                                                  false))

  root_block_device {
    volume_size = lookup(each.value, "root_volume_size", local.worker_group_defaults[ "root_volume_size" ])
    volume_type = lookup(each.value, "root_volume_type", local.worker_group_defaults[ "root_volume_type" ])

    iops = lookup(each.value, "root_iops", local.worker_group_defaults[ "root_iops" ])

    delete_on_termination = true
  }

  /* add additional EBS block devices */
  dynamic "ebs_block_device" {
    for_each = lookup(each.value, "ebs_block_devices", local.worker_group_defaults[ "ebs_block_devices" ])

    content {
      device_name           = ebs_block_device.value.device_name
      volume_size           = ebs_block_device.value.size
      snapshot_id           = lookup(ebs_block_device.value, "snapshot_id", null)
      volume_type           = lookup(ebs_block_device.value, "volume_type", "standard")
      encrypted             = lookup(ebs_block_device.value, "encrypted", false)
      iops                  = lookup(ebs_block_device.value, "iops", null)
      delete_on_termination = lookup(ebs_block_device.value, "delete_on_termination", true)
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "worker_per_az" {
  for_each = local.worker_group_az_subnet

  name_prefix = format("%s-%s-%s-", var.cluster_name,
                                    each.value.name,
                                    each.value.availability_zone)

  launch_configuration = aws_launch_configuration.worker[each.value.index].id

  desired_capacity = ceil((lookup(var.worker_group[each.value.index], "desired_capacity",
                                                                local.worker_group_defaults["desired_capacity"]) - each.value.subnet_index) / each.value.availability_zone_count)
  max_size         = ceil((lookup(var.worker_group[each.value.index], "max_size",
                                                                local.worker_group_defaults["max_size"]) - each.value.subnet_index) / each.value.availability_zone_count)
  min_size         = ceil((lookup(var.worker_group[each.value.index], "min_size",
                                                                local.worker_group_defaults["min_size"]) - each.value.subnet_index) / each.value.availability_zone_count)

  protect_from_scale_in = lookup(var.worker_group[each.value.index], "protect_from_scale_in",
                                                                     local.worker_group_defaults["protect_from_scale_in"])

 /* network settings */
 vpc_zone_identifier = [ each.value.subnet_id ]

  lifecycle {
    ignore_changes = [ desired_capacity ]
  }

  /* add label tags */
  dynamic "tag" {
    for_each = lookup(local.label_tags, each.value.index, {})

    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }

  /* add taint tags */
  dynamic "tag" {
    for_each = lookup(local.label_taints, each.value.index, {})

    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }

  dynamic "tag" {
    for_each = var.tags

    content {
      key = tag.key
      value = tag.value
      propagate_at_launch = true
    }
  }

  tag {
    key                 = "Name"
    value               = format("%s-%s", aws_eks_cluster.this.name, each.value.name)
    propagate_at_launch = true
  }

  tag {
    key                 = "kubernetes.io/cluster/${aws_eks_cluster.this.name}"
    value               = "owned"
    propagate_at_launch = true
  }

  tag {
    key                 = "k8s.io/cluster-autoscaler/${lookup(var.worker_group[each.value.index], "autoscaling_enabled", local.worker_group_defaults[ "autoscaling_enabled" ]) ? "enabled" : "disabled"}"
    value               = true
    propagate_at_launch = true
  }
}

/* configure worker authentication */
data "template_file" "worker_aws_auth" {
  //count = var.eks_worker_role_arn != null ? 0 : 1

/*
FIX ME: cleanup
resource "aws_iam_instance_profile" "worker" {
  name = format("EKS_worker.%s", var.cluster_name)

  role = var.eks_worker_role_arn != null ? var.eks_worker_role_arn : aws_iam_role.worker[0].name

  tags = merge(var.tags, local.tags)
}
*/

  template = file("${path.module}/templates/config-map-aws-auth.json.tmpl")

  vars = {
    worker_role_arn = var.eks_worker_role_arn != null ? var.eks_worker_role_arn : aws_iam_role.worker[0].arn
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
    git_url         = lookup(var.flux_config, "git_url")
    flux_image      = lookup(var.flux_config, "flux_image", lookup(var.flux_default_config, "flux_image"))
    helm_image      = lookup(var.flux_config, "helm_image", lookup(var.flux_default_config, "helm_image"))
    memcached_image = lookup(var.flux_config, "memcached_image", lookup(var.flux_default_config, "memcached_image"))
    cluster_dns_ip  = cidrhost(var.kubernetes_service_cidr, 10)
  }
}

resource "null_resource" "apply_flux_deployment" {
  count = local.enable_flux

  provisioner "local-exec" {
    command = "${path.module}/kubectl_apply.sh '${data.template_file.kubeconfig_json.rendered}' '${data.template_file.flux_deployment[0].rendered}'"
  }

  triggers = {
    cluster_id = aws_eks_cluster.this.id
  }

  /* only run after the cluster is up */
  depends_on = [
    aws_eks_cluster.this
  ]
}

/* tag subnets accordingly
   (https://github.com/kubernetes/kubernetes/blob/master/staging/src/k8s.io/legacy-cloud-providers/aws/aws.go) */
resource "aws_ec2_tag" "private" {
  for_each = toset(var.worker_subnet_id)

  resource_id = each.key

  key   = "kubernetes.io/role/internal-elb"
  value = "true"
}

resource "aws_iam_openid_connect_provider" "this" {
  count = local.enable_iam_service_accounts

  url = aws_eks_cluster.this.identity[0].oidc[0].issuer

  client_id_list = [
    "sts.amazonaws.com"
  ]

  thumbprint_list = []

  tags = merge(var.tags, local.tags)
}
