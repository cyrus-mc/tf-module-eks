module "eks" {
  source = "../"

  cluster_name    = "development"
  cluster_version = "1.11"

  cluster_subnet_id = [ "subnet-5a305f13", "subnet-063f6b61", "subnet-77325d3e", "subnet-b1386cd6" ]
  worker_subnet_id  = [ "subnet-77325d3e", "subnet-b1386cd6" ]

  worker_group = {
    one = {
      instance_type      = "t3.small"
      desired_capacity   = 2
      min_size           = 0
      image_id           = "ami-0dcb143eaaa2351b7"
      settings           = {
        node_labels = {
          "kiam/nodetype" = "server",
          "kubernetes.io/role" = "kiam"
        },
        ENFORCE_NODE_ALLOCATABLE = "pods",
        DNS_CLUSTER_IP           = "169.254.20.10"
      }
    },
    two = {
      instance_type      = "t3.xlarge"
      desired_capacity   = 2
      min_size           = 0
      image_id           = "ami-0dcb143eaaa2351b7"
      settings           = {
        node_labels = {
          "kubernetes.io/role" = "infrastructure"
        },
        ENFORCE_NODE_ALLOCATABLE = "pods",
        KUBELET_EXTRA_ARGS       = "--system-reserved=cpu=100m,memory=512Mi"
        DNS_CLUSTER_IP           = "169.254.20.10"
      }
//      ebs_block_devices = [
 //       {
  //        device_name = "/dev/sda"
   //       size = "100"
    //    }
     // ]
    }
  }

  worker_group_defaults = {
    key_name = "development_operations"
    ebs_block_devices = [
      {
        device_name = "/dev/sda"
        size = "100"
      }
    ]
  }

  flux_config = {
    enable = true
    git_url = format("git@bitbucket.org:dat/gitops-dev.git")
  }
}
