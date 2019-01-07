###############################################
#         Local Variable definitions          #
###############################################
locals {

  worker_ami = "${coalesce(join("", data.aws_ami.eks_worker.*.id), var.worker_ami)}"

  cluster_create_security_group = "${var.cluster_security_group_id == "" ? 1 : 0}"
  worker_create_security_group  = "${var.worker_security_group_id == "" ? 1 : 0}"

  cluster_security_group_id = "${coalesce(join("", aws_security_group.cluster.*.id), var.cluster_security_group_id)}"
  worker_security_group_id  = "${coalesce(join("", aws_security_group.worker.*.id), var.worker_security_group_id)}"

  /*
    Default tags (loacl so you can't over-ride)
  */
  tags = {
    builtWith         = "terraform"
    KubernetesCluster = "${var.name}"
  }

}


/* Name of the cluster */
variable "name" {}

/* Desired Kubernetes master version */
variable "eks_version" {}

variable "cluster_create_timeout" { default = "15m" }
variable "cluster_update_timeout" { default = "60m" }
variable "cluster_delete_timeout" { default = "15m" }

/* networking settings */
variable "cluster_subnet_id"         { type = "list" }
variable "cluster_security_group_id" { default = "" }

variable "cluster_role_arn" {}


/* configure worker nodes */
variable "worker_ami" { default = "" }

variable "worker_subnet_id"         { type = "list" }
variable "worker_security_group_id" { default = "" }

variable "worker_role_arn" {}

variable "worker_instance_profile" {}
