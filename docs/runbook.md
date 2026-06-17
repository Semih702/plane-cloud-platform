# Runbook

## First Deploy

1. Create the GitHub OIDC role:

   ```bash
   chmod +x scripts/bootstrap-oidc.sh
   ./scripts/bootstrap-oidc.sh --repo <OWNER>/<REPO> --branch main --profile <AWS_PROFILE>
   ```

2. Add the printed ARN as the GitHub secret `AWS_GITHUB_OIDC_ROLE_ARN`.
3. Run `Terraform Bootstrap` with `action=apply`.
4. Run `Terraform Prod` with `action=plan`.
5. Review the plan.
6. Run `Terraform Prod` with `action=apply`.

## Find The Plane URL

```bash
aws eks update-kubeconfig --name plane-prod-eks --region eu-west-1
kubectl get ingress plane-ingress -n plane
```

Use the ALB hostname unless `PLANE_APP_HOST` points to it through DNS.

## Update

Run `Terraform Prod` with `action=plan`, review the plan, then run `action=apply`.

Changing service modes can add or remove managed resources. Review plan output carefully before applying.

## Common Failures

- Missing `AWS_GITHUB_OIDC_ROLE_ARN`: configure the repository secret after running the OIDC helper.
- Backend bucket missing: run `Terraform Bootstrap` with `action=apply`.
- EKS API not reachable from GitHub-hosted runners: keep public endpoint enabled or run Actions on a network that can reach the private endpoint.
- AWS quota errors: check NAT Gateway, Elastic IP, EKS, RDS, Amazon MQ, ElastiCache, and instance-type availability in the selected region.
- External mode missing secret: check [service-modes.md](service-modes.md) for the required GitHub secrets.

## Teardown

There is no destructive workflow by default. Run `terraform destroy` manually from a trusted workstation after configuring the same backend and variables used by the workflows.
