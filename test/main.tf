module "eks" {
  source = "../"

  cluster_name    = "development"
  cluster_version = "1.11"

  cluster_subnet_id = [ "subnet-5a305f13", "subnet-063f6b61", "subnet-77325d3e", "subnet-b1386cd6" ]
  worker_subnet_id  = [ "subnet-77325d3e", "subnet-b1386cd6" ]

  worker_group_defaults = {
    key_name = "development_operations"
  }
}

