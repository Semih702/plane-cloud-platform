# Plane Cloud Deployment on AWS

This repository contains the infrastructure and deployment configuration for running Plane on AWS.

The goal is to manage cloud infrastructure and application delivery from a single repository, while keeping concerns separated logically:

- `terraform/`: infrastructure provisioning (AWS network and, later, platform resources)
- `helm/`: application deployment configuration (Plane Helm wrapper chart and environment values)

## Why this repository exists

We are building a production-oriented Plane setup for a small team (up to ~20 users) on AWS.

The initial focus is a clean and extensible network foundation for EKS-based deployment, with application-level services and sizing decisions to be finalized incrementally.

## Repository layout

- `terraform/environments/prod`: production environment Terraform root module
- `terraform/environments/bootstrap`: one-time backend bootstrap (S3 state bucket + DynamoDB lock table)
- `terraform/modules/vpc`: reusable VPC module
- `helm/plane`: Plane wrapper chart
- `helm/plane/values/dev.yaml`: current starting values for development overrides

## Current AWS network design (implemented)

Region: `eu-west-1`

VPC:

- CIDR: `172.26.0.0/16`
- DNS support: enabled
- DNS hostnames: enabled

Subnets across 3 Availability Zones:

- Public:
  - `172.26.0.0/22`
  - `172.26.4.0/22`
  - `172.26.8.0/22`
- Private:
  - `172.26.12.0/22`
  - `172.26.16.0/22`
  - `172.26.20.0/22`

Routing and egress:

- 1 Internet Gateway
- 1 public route table (associated with all public subnets)
- 3 private route tables (one per private subnet/AZ)
- 3 NAT Gateways (one per AZ)

### Why 3 NAT Gateways?

We intentionally use one NAT Gateway per AZ to avoid cross-AZ egress dependencies and improve availability.

If a single AZ has issues, workloads in other AZs keep outbound internet access via their local NAT Gateway.

## Deployment approach

Terraform manages the AWS infrastructure baseline.

Helm manages Plane deployment configuration and environment-specific overrides.

This structure allows us to evolve infrastructure and app delivery independently while still operating from one repository.

## Plane Helm Bootstrap

To install Plane charts locally before deployment:

```powershell
helm repo add makeplane https://helm.plane.so
helm repo update
```

The wrapper chart is located at `helm/plane` and environment overrides start with `helm/plane/values/dev.yaml`.

## Plane Storage Notes

- EKS now uses managed `aws-ebs-csi-driver` addon for dynamic PVC provisioning.
- Wrapper chart creates `gp3-csi` StorageClass and Plane stateful components use it explicitly.
- MinIO is disabled in `helm/plane/values/dev.yaml`; Plane document storage is configured for direct S3 usage.
- Replace placeholder S3 credentials in `helm/plane/values/dev.yaml` with real secrets before production use.

## GitHub CI/CD (OIDC)

GitHub Actions is configured to run Terraform using AWS OIDC federation instead of long-lived access keys.

- Workflow file: `.github/workflows/terraform-prod.yml`
- Bootstrap workflow: `.github/workflows/terraform-bootstrap.yml`
- OIDC setup guide: `.github/README-OIDC.md`

Behavior:

- Bootstrap workflow manages remote-state prerequisites (S3 + DynamoDB)
- Pull requests run `terraform init`, `validate`, and `plan`
- Manual dispatch supports `plan` and `apply`
- `apply` runs in GitHub Environment `prod` for approval-gated changes

Required GitHub secrets:

- `AWS_GITHUB_OIDC_ROLE_ARN`

## Unified Terraform + Helm Workflow

Deployment is handled in a single pipeline:

- Workflow file: `.github/workflows/terraform-prod.yml`
- PR: Terraform `init/validate/plan` + Helm `dependency update/lint/template`
- Main push or manual `apply`: Terraform apply first, then Helm upgrade with `--atomic --wait`
- Target cluster: `openproject-prod-eks`
- Target namespace/release: `plane-dev`

## Bootstrap First (Best Practice)

For a fresh AWS account, run bootstrap once before prod:

1. Run workflow `.github/workflows/terraform-bootstrap.yml` with `action=apply`
2. This creates:
   - S3 state bucket: `openproject-cloud-platform-tfstate-<account-id>`
   - DynamoDB lock table: `openproject-cloud-platform-tf-locks`
3. Then run normal prod workflow `.github/workflows/terraform-prod.yml`

## Workflow Runbook

Use GitHub Actions workflow `Terraform Prod` for controlled infrastructure changes.

1. Open a pull request for Terraform changes.
2. PR automatically runs `init`, `validate`, and `plan`.
3. Merge to `main` after review.
4. Push to `main` automatically triggers `apply` (approval-gated by `prod` environment if enabled).

Recommended:

- Keep direct local `terraform apply` disabled in team process.
- Use pull requests for all Terraform edits so plan runs are visible before apply.

## Terraform State Backend

Production Terraform uses an S3 remote backend with DynamoDB locking.

- Backend bucket pattern: `openproject-cloud-platform-tfstate-<account-id>`
- Lock table: `openproject-cloud-platform-tf-locks`

Bootstrap resources are managed by `terraform/environments/bootstrap` and should be applied once per AWS account (via bootstrap workflow).

For portability across fresh AWS accounts, the CI workflow also ensures
`AWSServiceRoleForRDS` exists before Terraform runs.

## IAM Policy Sync Guide (No Manual Copy/Paste)

Instead of pasting policy JSON in the AWS Console, sync the repo policy file directly with AWS CLI.

Prerequisites:

- AWS CLI installed
- An admin-capable profile (example below uses `personal`)
- Existing role name: `github-actions-terraform-prod`

Command:

```powershell
aws iam put-role-policy `
  --role-name github-actions-terraform-prod `
  --policy-name terraform-prod-policy `
  --policy-document file://.github/iam/terraform-prod-policy.json `
  --profile personal
```

Verify:

```powershell
aws iam get-role-policy `
  --role-name github-actions-terraform-prod `
  --policy-name terraform-prod-policy `
  --profile personal
```

When to run this:

- After any change to `.github/iam/terraform-prod-policy.json`
- Before re-running failing workflows caused by missing IAM permissions

## Future roadmap

Planned additions include:

- EKS cluster and supporting AWS modules
- Argo CD for GitOps-based continuous delivery
- Renovate for dependency/chart update automation
- Automated, low-downtime Plane rollouts as Helm chart updates are published and promoted through controlled environments

## Notes

- Use the correct AWS profile/account before running Terraform.
- Run `terraform plan` before `terraform apply` for safer changes.

## Zero-to-Deploy Guide

Use this checklist to bring up the project from scratch in a new AWS account.

1. Create GitHub repository secrets
   - Add `AWS_GITHUB_OIDC_ROLE_ARN` in repository secrets.

2. Configure AWS IAM/OIDC once (manual)
   - Create GitHub OIDC identity provider (`token.actions.githubusercontent.com`) if missing.
   - Create role `github-actions-terraform-prod` with trust policy for your repo/branch.
   - Attach inline policy from `.github/iam/terraform-prod-policy.json`.
   - Sync policy with:
     ```powershell
     aws iam put-role-policy `
       --role-name github-actions-terraform-prod `
       --policy-name terraform-prod-policy `
       --policy-document file://.github/iam/terraform-prod-policy.json `
       --profile personal
     ```

3. Run bootstrap once (manual trigger in GitHub Actions)
   - Open workflow `Terraform Bootstrap`.
   - Run with `action=apply`.
   - This creates:
     - `openproject-cloud-platform-tfstate-<account-id>` (S3 backend bucket)
     - `openproject-cloud-platform-tf-locks` (DynamoDB lock table)

4. Run production workflow
   - Open workflow `Terraform Prod`.
   - Run `action=apply` (or push to `main` after PR flow).
   - Pipeline order:
     - Terraform init/validate/plan
     - Terraform apply
     - Helm upgrade/install for Plane (`--atomic --wait`)

5. Verify cluster and app
   - `kubectl get pods -n plane-dev`
   - `kubectl get jobs -n plane-dev`
   - `kubectl get pvc -n plane-dev`
   - Ensure migration job is `Complete`, core pods are `Running/Ready`, PVCs are `Bound`.

6. Post-setup hardening (recommended)
   - Move S3 credentials out of `helm/plane/values/dev.yaml`.
   - Use Secrets Manager + Kubernetes secret sync (or equivalent).
