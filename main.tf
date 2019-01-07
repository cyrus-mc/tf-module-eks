/* query AmazonEKS AMI for specific EKS version */
data aws_ami "eks_worker" {
  /* only query if we didn't supply our own AMI */
  count = "${var.worker_ami == "" ? 1 : 0}"

  filter {
    name = "name"
    values = [ "amazon-eks-node-${var.eks_version}-*" ]
  }

  most_recent = true
  owners      = [ "602401143452" ]
}

data aws_subnet "selected" {
  id = "${var.cluster_subnet_id[0]}"
}

/* create worker security group */
resource aws_security_group "worker" {
  count = "${local.worker_create_security_group}"

  name_prefix = "${format("eks_worker-%s-", var.name)}"

  vpc_id = "${data.aws_subnet.selected.vpc_id}"
}

resource aws_security_group_rule "workers_self" {
  count = "${local.worker_create_security_group}"

  security_group_id = "${aws_security_group.worker.id}"

  source_security_group_id = "${aws_security_group.worker.id}"
  protocol                 = "-1"
  from_port                = 0
  to_port                  = 65535
  type                     = "ingress"
}

resource aws_security_group_rule "worker_cluster" {
  count = "${local.worker_create_security_group}"

  security_group_id = "${aws_security_group.worker.id}"

  source_security_group_id = "${local.cluster_security_group_id}"
  protocol                 = "tcp"
  from_port                = 0
  to_port                  = 65535
  type                     = "ingress"
}

resource aws_security_group_rule "worker_cluster_https" {
  count = "${local.worker_create_security_group}"

  security_group_id = "${aws_security_group.worker.id}"

  source_security_group_id = "${local.cluster_security_group_id}"
  protocol                 = "tcp"
  from_port                = 443
  to_port                  = 443
  type                     = "ingress"
}

/* create control plane security group */
resource aws_security_group "cluster" {
  count = "${local.cluster_create_security_group}"

  name_prefix = "${format("eks_master-%s-", var.name)}"

  vpc_id = "${data.aws_subnet.selected.vpc_id}"
}

resource aws_security_group_rule "cluster_egress" {
  count = "${local.cluster_create_security_group}"

  security_group_id = "${aws_security_group.cluster.id}"

  cidr_blocks = [ "0.0.0.0/0" ]
  protocol    = "-1"
  from_port   = 0
  to_port     = 0
  type        = "egress"
}

resource aws_security_group_rule "cluster_worker_ingress" {
  count = "${local.cluster_create_security_group}"

  security_group_id = "${aws_security_group.cluster.id}"

  source_security_group_id = "${local.worker_security_group_id}"
  protocol                 = "TCP"
  from_port                = 443
  to_port                  = 443
  type      = "ingress"
}

resource aws_eks_cluster "main" {
  /* name of the cluster */
  name = "${var.name}"

  /* desired Kubernetes master version */
  version = "${var.eks_version}"

  role_arn = "${var.cluster_role_arn}"

  timeouts {
    create = "${var.cluster_create_timeout}"
    update = "${var.cluster_update_timeout}"
    delete = "${var.cluster_delete_timeout}"
  }

  /* list all subnets that belong to cluster (private and public) */
  vpc_config {
    security_group_ids = [ "${var.cluster_security_group_id}" ]
    subnet_ids         = [ "${var.cluster_subnet_id}" ]
  }
}

data aws_region "current" {}

locals {
  demo-node-userdata = <<USERDATA
#!/bin/bash
set -o xtrace
/etc/eks/bootstrap.sh --apiserver-endpoint '${aws_eks_cluster.main.endpoint}' --b64-cluster-ca '${aws_eks_cluster.main.certificate_authority.0.data}' '${var.name}'
USERDATA
}

resource aws_launch_configuration "main" {
  associate_public_ip_address = false
  iam_instance_profile        = "${var.worker_instance_profile}"
  image_id                    = "${local.worker_ami}"
  instance_type               = "m4.large"
  name_prefix                 = "terraform-eks-demo"
  security_groups             = [ "${var.worker_security_group_id}" ]

  key_name                    = "development_operations"

  user_data_base64            = "${base64encode(local.demo-node-userdata)}"

  lifecycle {
    create_before_destroy = true
  }
}

resource aws_autoscaling_group "main" {
  desired_capacity     = 1
  launch_configuration = "${aws_launch_configuration.main.id}"
  max_size             = 2
  min_size             = 1
  name                 = "terraform-eks-demo"
  //vpc_zone_identifier  = [ "${var.subnet_id}" ] vpc_zone_identifier = [ "subnet-77325d3e", "subnet-b1386cd6" ]

  tag {
    key                 = "Name"
    value               = "terraform-eks-demo"
    propagate_at_launch = true
  }

  tag {
    key                 = "kubernetes.io/cluster/${var.name}"
    value               = "owned"
    propagate_at_launch = true
  }
}
