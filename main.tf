/* query AmazonEKS AMI for specific EKS version */
data aws_ami "eks_worker" {
  /* only query if we didn't supply our own AMI */
  count = "${var.worker_ami == "" ? 1 : 0}"

  filter {
    name = "name"
    values = [ "amazon-eks-node-${var.cluster_version}-*" ]
  }

  most_recent = true
  owners      = [ "602401143452" ]
}

data aws_subnet "selected" {
  id = "${var.cluster_subnet_id[0]}"
}

/* create worker security group */
resource aws_security_group "worker" {
  name_prefix = "${format("eks_worker-%s-", var.cluster_name)}"

  vpc_id = "${data.aws_subnet.selected.vpc_id}"

  tags = "${merge(var.tags, map(format("kubernetes.io/cluster/%s", aws_eks_cluster.main.name), "owned",
                                "Name", format("eks_worker_%s", aws_eks_cluster.main.name)))}"
}

resource aws_security_group_rule "worker_egress" {
  security_group_id = "${aws_security_group.worker.id}"

  cidr_blocks = [ "0.0.0.0/0" ]
  protocol    = "-1"
  from_port   = 0
  to_port     = 0
  type        = "egress"
}

resource aws_security_group_rule "workers_self" {
  security_group_id = "${aws_security_group.worker.id}"

  source_security_group_id = "${aws_security_group.worker.id}"
  protocol                 = "-1"
  from_port                = 0
  to_port                  = 65535
  type                     = "ingress"
}

resource aws_security_group_rule "worker_cluster" {
  security_group_id = "${aws_security_group.worker.id}"

  source_security_group_id = "${aws_security_group.cluster.id}"
  protocol                 = "tcp"
  from_port                = 0
  to_port                  = 65535
  type                     = "ingress"
}

resource aws_security_group_rule "worker_cluster_https" {
  security_group_id = "${aws_security_group.worker.id}"

  source_security_group_id = "${aws_security_group.cluster.id}"
  protocol                 = "tcp"
  from_port                = 443
  to_port                  = 443
  type                     = "ingress"
}

resource aws_security_group_rule "worker_supplied" {
  count = "${length(var.worker_security_group_rule)}"

  security_group_id = "${aws_security_group.worker.id}"

  cidr_blocks = [ "${lookup(var.worker_security_group_rule[count.index], "cidr_blocks")}" ]
  protocol    = "${lookup(var.worker_security_group_rule[count.index], "protocol")}"
  from_port   = "${lookup(var.worker_security_group_rule[count.index], "from_port")}"
  to_port     = "${lookup(var.worker_security_group_rule[count.index], "to_port")}"
  type        = "ingress"
}

/* create control plane security group */
resource aws_security_group "cluster" {
  name_prefix = "${format("eks_master-%s-", var.cluster_name)}"

  vpc_id = "${data.aws_subnet.selected.vpc_id}"

  tags = "${merge(var.tags, map(format("kubernetes.io/cluster/%s", var.cluster_name), "owned",
                                "Name", format("eks_cluster_%s", var.cluster_name)))}"
}

resource aws_security_group_rule "cluster_egress" {
  security_group_id = "${aws_security_group.cluster.id}"

  cidr_blocks = [ "0.0.0.0/0" ]
  protocol    = "-1"
  from_port   = 0
  to_port     = 0
  type        = "egress"
}

resource aws_security_group_rule "cluster_worker_ingress" {
  security_group_id = "${aws_security_group.cluster.id}"

  source_security_group_id = "${aws_security_group.worker.id}"
  protocol                 = "TCP"
  from_port                = 443
  to_port                  = 443
  type      = "ingress"
}

resource aws_security_group_rule "cluster_supplied" {
  count = "${length(var.cluster_security_group_rule)}"

  security_group_id = "${aws_security_group.worker.id}"

  cidr_blocks = [ "${lookup(var.cluster_security_group_rule[count.index], "cidr_blocks")}" ]
  protocol    = "${lookup(var.cluster_security_group_rule[count.index], "protocol")}"
  from_port   = "${lookup(var.cluster_security_group_rule[count.index], "from_port")}"
  to_port     = "${lookup(var.cluster_security_group_rule[count.index], "to_port")}"
  type        = "ingress"
}

resource aws_eks_cluster "main" {
  /* name of the cluster */
  name = "${var.cluster_name}"

  /* desired Kubernetes master version */
  version = "${var.cluster_version}"

  role_arn = "${var.cluster_role_arn}"

  timeouts {
    create = "${var.cluster_create_timeout}"
    update = "${var.cluster_update_timeout}"
    delete = "${var.cluster_delete_timeout}"
  }

  /* list all subnets that belong to cluster (private and public) */
  vpc_config {
    security_group_ids = [ "${aws_security_group.cluster.id}" ]
    subnet_ids         = [ "${var.cluster_subnet_id}" ]
  }
}

/* create worker autoscaling groups */
resource null_resource "tags_as_list_of_maps" {
  count = "${length(keys(var.tags))}"

  triggers {
    key                 = "${element(keys(var.tags), count.index)}"
    value               = "${element(values(var.tags), count.index)}"
    propagate_at_launch = true
  }
}

data template_file "worker_userdata" {
  count = "${var.worker_count}"

  template = "${file("${path.module}/templates/userdata.sh.tpl")}"

  vars {
    cluster_name        = "${aws_eks_cluster.main.name}"
    endpoint            = "${aws_eks_cluster.main.endpoint}"
    cluster_auth_base64 = "${aws_eks_cluster.main.certificate_authority.0.data}"
    kubelet_extra_args  = "${lookup(var.worker_group[count.index], "kubelet_extra_args",
                                                                   local.worker_group_defaults["kubelet_extra_args"])}"
  }
}

resource aws_launch_configuration "worker" {
  count = "${var.worker_count}"

  name_prefix = "${format("eks-%s-%s-", aws_eks_cluster.main.name,
                                    lookup(var.worker_group[count.index], "name", count.index))}"

  enable_monitoring = "${lookup(var.worker_group[count.index], "enable_monitoring",
                                                               local.worker_group_defaults["enable_monitoring"])}"

  associate_public_ip_address = "${lookup(var.worker_group[count.index], "public_ip",
                                                                         local.worker_group_defaults["public_ip"])}"
  security_groups = [ "${aws_security_group.worker.id}" ]


  iam_instance_profile = "${var.worker_instance_profile}"
  image_id = "${lookup(var.worker_group[count.index], "image_id",
                                                      local.worker_group_defaults["image_id"])}"
  instance_type        = "${lookup(var.worker_group[count.index], "instance_type",
                                                                  local.worker_group_defaults["instance_type"])}"
  key_name             = "${lookup(var.worker_group[count.index], "key_name",
                                                                  local.worker_group_defaults["key_name"])}"
  user_data_base64     = "${base64encode(element(data.template_file.worker_userdata.*.rendered, count.index))}"

  /* only enable ebs optimized for instance types that allow it */
  ebs_optimized = "${lookup(var.worker_group[count.index], "ebs_optimized",
                                                           lookup(local.ebs_optimized, lookup(var.worker_group[count.index], "instance_type",
                                                                                                                             local.worker_group_defaults["instance_type"]),
                                                                                       false))}"
  root_block_device {
    volume_size          = "${lookup(var.worker_group[count.index], "root_volume_size",
                                                                    local.worker_group_defaults["root_volume_size"])}"
    volume_type          = "${lookup(var.worker_group[count.index], "root_volume_type",
                                                                    local.worker_group_defaults["root_volume_type"])}"
    iops                 = "${lookup(var.worker_group[count.index], "root_iops",
                                                                    local.worker_group_defaults["root_iops"])}"
    delete_on_termination = true
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource aws_autoscaling_group "worker" {
  count = "${var.worker_count}"

  name_prefix = "${format("eks-%s-%s-", aws_eks_cluster.main.name,
                                   lookup(var.worker_group[count.index], "name", count.index))}"

  launch_configuration = "${element(aws_launch_configuration.worker.*.id, count.index)}"

  desired_capacity = "${lookup(var.worker_group[count.index], "desired_capacity",
                                                              local.worker_group_defaults["desired_capacity"])}"
  max_size         = "${lookup(var.worker_group[count.index], "max_size",
                                                              local.worker_group_defaults["max_size"])}"
  min_size         = "${lookup(var.worker_group[count.index], "min_size",
                                                              local.worker_group_defaults["min_size"])}"

  protect_from_scale_in = "${lookup(var.worker_group[count.index], "protect_from_scale_in",
                                                                     local.worker_group_defaults["protect_from_scale_in"])}"

  /* network settings */
  vpc_zone_identifier = [ "${split(",", coalesce(lookup(var.worker_group[count.index], "subnets", ""),
                                                 local.worker_group_defaults["subnets"]))}" ]

  lifecycle {
    ignore_changes = [ "desired_capacity" ]
  }

  tags = [ "${concat(
                list(
                  map("key", "Name",
                      "value", format("eks-%s-%s", aws_eks_cluster.main.name,
                                                   lookup(var.worker_group[count.index], "name", count.index)),
                      "propagate_at_launch", true),
                  map("key", "kubernetes.io/cluster/${aws_eks_cluster.main.name}",
                      "value", "owned",
                      "propagate_at_launch", true),
                  map("key", "k8s.io/cluster-autoscaler/${lookup(var.worker_group[count.index], "autoscaling_enabled",
                                                                                                local.worker_group_defaults["autoscaling_enabled"]) == 1 ? "enabled" : "disabled"}",
                      "value", "true",
                      "propagate_at_launch", false)
                ),
                local.asg_tags
              )}"
         ]
}

/* configure worker authentication */
data template_file "worker_aws_auth" {
  template = "${file("${path.module}/templates/config-map-aws-auth.yaml.tpl")}"

  vars {
    worker_role_arn = "${var.worker_role_arn}"
  }
}

resource local_file "worker_aws_auth" {
  content = "${data.template_file.worker_aws_auth.rendered}"
  filename = "./config-map-aws-auth_${var.cluster_name}.yaml"
}


/* configure kubectl */
data template_file "aws_authenticator_env_vars" {
  count = "${length(var.kubeconfig_aws_authenticator_env_vars)}"

  template = <<EOF
        - name: $${key}
          value: $${value}
EOF

  vars {
    key   = "${element(keys(var.kubeconfig_aws_authenticator_env_vars), count.index)}"
    value = "${element(values(var.kubeconfig_aws_authenticator_env_vars), count.index)}"
  }
}

data template_file "kubeconfig" {
  template = "${file("${path.module}/templates/kubeconfig.tpl")}"

  vars {
    cluster_name                     = "${aws_eks_cluster.main.name}"
    kubeconfig_name                  = "${local.kubeconfig_name}"
    endpoint                         = "${aws_eks_cluster.main.endpoint}"
    cluster_auth_base64              = "${aws_eks_cluster.main.certificate_authority.0.data}"
    aws_authenticator_env_variables  = "${length(var.kubeconfig_aws_authenticator_env_vars) > 0 ? "      env:\n${join("\n", data.template_file.aws_authenticator_env_vars.*.rendered)}" : ""}"
  }
}

resource local_file "kubeconfig" {
  content = "${data.template_file.kubeconfig.rendered}"
  filename = "./kubeconfig_${var.cluster_name}"
}

resource null_resource "update_worker_aws_auth" {
  provisioner "local-exec" {
    command = "for i in {1..5}; do kubectl apply -f ./config-map-aws-auth_${var.cluster_name}.yaml --kubeconfig ./kubeconfig_${var.cluster_name} && break || sleep 10; done"
  }

  triggers {
    config_map_rendered = "${data.template_file.worker_aws_auth.rendered}"
  }

  /* only run after the cluster is up */
  depends_on = [ "aws_eks_cluster.main" ]
}

