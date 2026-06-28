# Runbook

## First Deploy

1. Create the GitHub OIDC role:

   - Create or reuse the GitHub OIDC provider for `https://token.actions.githubusercontent.com`.
   - Create an IAM role whose trust policy allows `repo:<OWNER>/<REPO>:ref:refs/heads/main`.
   - Attach `.github/iam/terraform-prod-policy.json` as an inline policy.

2. Add the printed ARN as the GitHub secret `AWS_GITHUB_OIDC_ROLE_ARN`.
3. Optional: if you want local `kubectl` access after deploy, set `EKS_CLUSTER_ADMIN_PRINCIPAL_ARNS_JSON` to a JSON array containing your administrator IAM user or role ARN.
4. Optional: if deploying into an existing EKS cluster, set the variables in [existing-cluster.md](existing-cluster.md) before planning.
5. Run `Terraform Bootstrap` with `action=apply`.
6. Run `Terraform Prod` with `action=plan`.
7. Review the plan.
8. Run `Terraform Prod` with `action=apply`.

## Find The Plane URL

```bash
aws eks update-kubeconfig --name plane-prod-eks --region eu-west-1
kubectl get ingress plane-ingress -n plane
```

Use the ALB hostname unless `PLANE_APP_HOST` points to it through DNS.

For existing-cluster mode, replace `plane-prod-eks` with `EXISTING_EKS_CLUSTER_NAME`.
If your local IAM principal was not added to `EKS_CLUSTER_ADMIN_PRINCIPAL_ARNS_JSON`, get the ALB DNS name from AWS instead:

```bash
aws elbv2 describe-load-balancers --region eu-west-1 \
  --query "LoadBalancers[?contains(LoadBalancerName, 'k8s-plane')].DNSName" \
  --output text
```

## Update

Run `Terraform Prod` with `action=plan`, review the plan, then run `action=apply`.

Changing service modes can add or remove managed resources. Review plan output carefully before applying.

## Common Failures

- Missing `AWS_GITHUB_OIDC_ROLE_ARN`: configure the repository secret with the IAM role ARN after creating the GitHub OIDC role.
- `Not authorized to perform sts:AssumeRoleWithWebIdentity`: make sure the OIDC trust policy allows `repo:<owner>/<repo>:ref:refs/heads/main` and that you ran the workflow from `main`.
- Backend bucket missing: run `Terraform Bootstrap` with `action=apply`.
- EKS API not reachable from GitHub-hosted runners: keep public endpoint enabled or run Actions on a network that can reach the private endpoint.
- Existing cluster variables missing: set `EXISTING_EKS_CLUSTER_NAME`, and set the existing VPC/subnet variables if any data service remains AWS-managed.
- AWS quota errors: check NAT Gateway, Elastic IP, EKS, RDS, Amazon MQ, ElastiCache, and instance-type availability in the selected region.
- External mode missing secret: check [service-modes.md](service-modes.md) for the required GitHub secrets.

## Teardown

There is no destructive workflow by default. Run `terraform destroy` manually from a trusted workstation after configuring the same backend and variables used by the workflows.
