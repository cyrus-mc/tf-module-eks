resource aws_iam_role "dev_cluster" {
  name = "terraform-eks-dev-cluster"

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "eks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY
}

resource aws_iam_role_policy_attachment "dev_cluster_AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = "${aws_iam_role.dev_cluster.name}"
}

resource aws_iam_role_policy_attachment "dev_cluster_AmazonEKSServicePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSServicePolicy"
  role       = "${aws_iam_role.dev_cluster.name}"
}

resource aws_iam_role "dev_worker" {
  name = "terraform-eks-dev-node"

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY
}

resource aws_iam_role_policy_attachment "dev_worker_AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = "${aws_iam_role.dev_worker.name}"
}

resource aws_iam_role_policy_attachment "dev_worker_AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = "${aws_iam_role.dev_worker.name}"
}

resource aws_iam_role_policy_attachment "dev_worker_AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = "${aws_iam_role.dev_worker.name}"
}

resource aws_iam_instance_profile "dev_worker" {
  name = "terraform-eks-dev-node"
  role = "${aws_iam_role.dev_worker.name}"
}

module "eks" {
  source = "../"

  cluster_name    = "development"
  cluster_version = "1.11.5"

  cluster_role_arn = "${aws_iam_role.dev_cluster.arn}"

  cluster_subnet_id = [ "subnet-5a305f13", "subnet-063f6b61", "subnet-77325d3e", "subnet-b1386cd6" ]
  worker_subnet_id  = [ "subnet-77325d3e", "subnet-b1386cd6" ]

  worker_role_arn         = "${aws_iam_role.dev_worker.arn}"
  worker_instance_profile = "${aws_iam_instance_profile.dev_worker.name}"

  worker_group_defaults {
    key_name = "development_operations"
  }
}
