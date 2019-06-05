output "cluster_id"       { value = aws_eks_cluster.main.id }
output "cluster_endpoint" { value = aws_eks_cluster.main.endpoint }
output "cluster_version"  { value = aws_eks_cluster.main.version }
output "cluster_certificate_authority_data" { value = aws_eks_cluster.main.certificate_authority[0].data }

# Though documented, not yet supported
# output "cluster_arn" { value = "${aws_eks_cluster.main.arn}" }

output "kubeconfig" { value = data.template_file.kubeconfig.rendered }
