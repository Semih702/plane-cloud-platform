# OpenProject Cloud Deployment on AWS

This repository contains the infrastructure and deployment configuration for running OpenProject on AWS.

The goal is to manage cloud infrastructure and application delivery from a single repository, while keeping concerns separated logically:

- `terraform/`: infrastructure provisioning (AWS network and, later, platform resources)
- `helm/`: application deployment configuration (OpenProject Helm wrapper chart and environment values)

## Why this repository exists

We are building a production-oriented OpenProject setup for a small team (up to ~20 users) on AWS.

The initial focus is a clean and extensible network foundation for EKS-based deployment, with application-level services and sizing decisions to be finalized incrementally.

## Repository layout

- `terraform/environments/prod`: production environment Terraform root module
- `terraform/modules/vpc`: reusable VPC module
- `helm/openproject`: OpenProject wrapper chart
- `helm/openproject/values/dev.yaml`: current starting values for development overrides

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

Helm manages OpenProject deployment configuration and environment-specific overrides.

This structure allows us to evolve infrastructure and app delivery independently while still operating from one repository.

## GitHub CI/CD (OIDC)

GitHub Actions is configured to run Terraform using AWS OIDC federation instead of long-lived access keys.

- Workflow file: `.github/workflows/terraform-prod.yml`
- OIDC setup guide: `.github/README-OIDC.md`

Behavior:

- Pull requests run `terraform init`, `validate`, and `plan`
- Manual dispatch supports `plan` and `apply`
- `apply` runs in GitHub Environment `prod` for approval-gated changes

Required GitHub secrets:

- `AWS_GITHUB_OIDC_ROLE_ARN`

## Workflow Runbook

Use GitHub Actions workflow `Terraform Prod` for controlled infrastructure changes.

1. Open a pull request for Terraform changes.
2. PR automatically runs `init`, `validate`, and `plan`.
3. Merge to `main` after review.
4. Push to `main` automatically triggers `apply` (approval-gated by `prod` environment if enabled).

Recommended:

- Keep direct local `terraform apply` disabled in team process.
- Use pull requests for all Terraform edits so plan runs are visible before apply.

## Future roadmap

Planned additions include:

- EKS cluster and supporting AWS modules
- Argo CD for GitOps-based continuous delivery
- Renovate for dependency/chart update automation
- Automated, low-downtime OpenProject rollouts as Helm chart updates are published and promoted through controlled environments

## Notes

- Use the correct AWS profile/account before running Terraform.
- Run `terraform plan` before `terraform apply` for safer changes.
