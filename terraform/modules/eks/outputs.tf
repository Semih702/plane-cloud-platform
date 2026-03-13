output "cluster_name" {
  description = "EKS cluster name"
  value       = aws_eks_cluster.this.name
}

output "cluster_arn" {
  description = "EKS cluster ARN"
  value       = aws_eks_cluster.this.arn
}

output "cluster_endpoint" {
  description = "EKS API endpoint"
  value       = aws_eks_cluster.this.endpoint
}

output "cluster_security_group_id" {
  description = "Security group managed by EKS control plane"
  value       = aws_eks_cluster.this.vpc_config[0].cluster_security_group_id
}

output "node_group_name" {
  description = "EKS managed node group name"
  value       = aws_eks_node_group.this.node_group_name
}

output "oidc_provider_arn" {
  description = "IAM OIDC provider ARN for this EKS cluster"
  value       = aws_iam_openid_connect_provider.eks.arn
}

output "oidc_issuer_hostpath" {
  description = "OIDC issuer hostpath (without https://)"
  value       = local.oidc_issuer_hostpath
}

output "aws_load_balancer_controller_irsa_role_arn" {
  description = "IRSA role ARN for aws-load-balancer-controller"
  value       = var.enable_aws_load_balancer_controller ? aws_iam_role.aws_load_balancer_controller_irsa[0].arn : null
}

output "cluster_autoscaler_irsa_role_arn" {
  description = "IRSA role ARN for cluster-autoscaler"
  value       = var.enable_cluster_autoscaler ? aws_iam_role.cluster_autoscaler_irsa[0].arn : null
}
