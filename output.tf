output "cluster_name"     { value = aws_eks_cluster.this.name }
output "cluster_id"       { value = aws_eks_cluster.this.id }
output "cluster_endpoint" { value = aws_eks_cluster.this.endpoint }
output "cluster_version"  { value = aws_eks_cluster.this.version }
output "cluster_certificate_authority_data" { value = aws_eks_cluster.this.certificate_authority[0].data }

# Though documented, not yet supported
# output "cluster_arn" { value = "${aws_eks_cluster.main.arn}" }

output "kubeconfig" {
  value = data.template_file.kubeconfig.rendered

  depends_on = [
    null_resource.apply_flux_deployment
  ]
}
output "kubeconfig_json" {
  value = data.template_file.kubeconfig_json.rendered

  depends_on = [
    null_resource.apply_flux_deployment
  ]
}

/* kiam outputs */
output "kiam_server_role_arn"  { value = join("", aws_iam_role.kiam.*.arn) }
output "identity_provider_arn" { value = join("", aws_iam_openid_connect_provider.this.*.arn) }

/* aws oidc outputs */
output "identity_provider_url" { value = join("", aws_iam_openid_connect_provider.this.*.url) }