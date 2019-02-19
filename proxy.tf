/* deploy proxy use to protect public EKS */
data template_file "proxy_user_data" {
  count = "${var.enable_proxy}"

  template = "${file("${path.module}/templates/user_data/proxy.tpl")}"

  vars {
    EKS_ENDPOINT = "${replace(aws_eks_cluster.main.endpoint, "/^https\\:\\/\\//", "")}"
  }
}

resource aws_security_group "proxy" {
  count = "${var.enable_proxy}"

  name_prefix = "${format("eks_proxy_%s-", aws_eks_cluster.main.name)}"

  vpc_id = "${data.aws_subnet.selected.vpc_id}"

  lifecycle {
    create_before_destroy = true
  }

  tags = "${merge(var.tags, map("Name", format("eks_proxy_%s", aws_eks_cluster.main.name)))}"
}

resource aws_security_group_rule "proxy_ingress_https" {
  count = "${var.enable_proxy}"

  type = "ingress"

  from_port   = 443
  to_port     = 443
  protocol    = "tcp"
  cidr_blocks = [ "0.0.0.0/0" ]

  security_group_id = "${aws_security_group.proxy.id}"
}

resource aws_security_group_rule "proxy_ingress_ssh" {
  count = "${var.enable_proxy}"

  type = "ingress"

  from_port   = 22
  to_port     = 22
  protocol    = "tcp"
  cidr_blocks = [ "0.0.0.0/0" ]

  security_group_id = "${aws_security_group.proxy.id}"
}

resource aws_security_group_rule "proxy_egress" {
  count = "${var.enable_proxy}"

  type = "egress"

  from_port   = 0
  to_port     = 0
  protocol    = -1
  cidr_blocks = [ "0.0.0.0/0" ]

  security_group_id = "${aws_security_group.proxy.id}"
}

/* allow this security group access to cluster security group */
resource aws_security_group_rule "proxy_cluster_ingress" {
  count = "${var.enable_proxy}"

  security_group_id = "${aws_security_group.cluster.id}"

  source_security_group_id = "${aws_security_group.proxy.id}"
  protocol                 = "TCP"
  from_port                = 443
  to_port                  = 443
  type                     = "ingress"
}


resource aws_instance "proxy" {
  count = "${var.enable_proxy}"

  ami           = "${var.proxy_ami}"
  instance_type = "${var.proxy_instance_type}"

  key_name  = "${local.proxy_key_name}"
  user_data = "${data.template_file.proxy_user_data.rendered}"

  /* place in the first subnet */
  //subnet_id                   = "${element(var.worker_subnet_id, 0)}"
  subnet_id                   = "${local.proxy_subnet_id}"
  vpc_security_group_ids      = [ "${aws_security_group.proxy.id}" ]
  associate_public_ip_address = false

  tags = "${merge(var.tags,
                  map("Name",
                      format("eks-%s-proxy", var.cluster_name)),
                  local.tags)}"
}
