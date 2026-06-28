# Runbook

## First Deploy

1. Create the GitHub OIDC role:

   ```bash
   chmod +x scripts/bootstrap-oidc.sh
   ./scripts/bootstrap-oidc.sh --repo <OWNER>/<REPO> --branch main --profile <AWS_PROFILE>
   ```

2. Add the printed ARN as the GitHub secret `AWS_GITHUB_OIDC_ROLE_ARN`.
3. Optional: if deploying into an existing EKS cluster, set the variables in [existing-cluster.md](existing-cluster.md) before planning.
4. Run `Terraform Bootstrap` with `action=apply` and approve the `prod` environment prompt when GitHub asks.
5. Run `Terraform Prod` with `action=plan`.
6. Review the plan.
7. Run `Terraform Prod` with `action=apply` and approve the `prod` environment prompt.

## Find The Plane URL

```bash
aws eks update-kubeconfig --name plane-prod-eks --region eu-west-1
kubectl get ingress plane-ingress -n plane
```

Use the ALB hostname unless `PLANE_APP_HOST` points to it through DNS.

For existing-cluster mode, replace `plane-prod-eks` with `EXISTING_EKS_CLUSTER_NAME`.

## Update

Run `Terraform Prod` with `action=plan`, review the plan, then run `action=apply`.

Changing service modes can add or remove managed resources. Review plan output carefully before applying.

## Common Failures

- Missing `AWS_GITHUB_OIDC_ROLE_ARN`: configure the repository secret after running the OIDC helper.
- `Not authorized to perform sts:AssumeRoleWithWebIdentity` in an apply job: make sure the OIDC trust policy allows `repo:<owner>/<repo>:environment:prod` as well as the `main` branch subject.
- Backend bucket missing: run `Terraform Bootstrap` with `action=apply`.
- EKS API not reachable from GitHub-hosted runners: keep public endpoint enabled or run Actions on a network that can reach the private endpoint.
- Existing cluster variables missing: set `EXISTING_EKS_CLUSTER_NAME`, and set the existing VPC/subnet variables if any data service remains AWS-managed.
- AWS quota errors: check NAT Gateway, Elastic IP, EKS, RDS, Amazon MQ, ElastiCache, and instance-type availability in the selected region.
- External mode missing secret: check [service-modes.md](service-modes.md) for the required GitHub secrets.

## Teardown

There is no destructive workflow by default. Run `terraform destroy` manually from a trusted workstation after configuring the same backend and variables used by the workflows.
