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

```bash
helm repo add makeplane https://helm.plane.so
helm repo update
```

The wrapper chart is located at `helm/plane` and environment overrides start with `helm/plane/values/dev.yaml`.

## Plane Storage Notes

- EKS now uses managed `aws-ebs-csi-driver` addon for dynamic PVC provisioning.
- Wrapper chart creates `gp3-csi` StorageClass and Plane stateful components use it explicitly.
- MinIO is disabled in `helm/plane/values/dev.yaml`; Plane document storage is configured for direct S3 usage.
- Plane workloads use IRSA (IAM Role for Service Account) for S3 access; no static S3 access key is required.
- Wrapper chart creates Kubernetes Secret `plane-dev-doc-store-secrets` during `helm upgrade/install`, so app deploy is self-contained.

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
- `PLANE_S3_ENDPOINT_URL` (optional for AWS S3; can be empty)

## Unified Terraform + Helm Workflow

Deployment is handled in a single pipeline:

- Workflow file: `.github/workflows/terraform-prod.yml`
- PR: Terraform `init/validate/plan` + Helm `dependency update/lint/template`
- Main push or manual `apply`: Terraform apply first, then Helm upgrade with `--rollback-on-failure --wait --wait-for-jobs`
- Target cluster: `plane-prod-eks`
- Target namespace/release: `plane-dev`

## Manual Helm Upgrade Runbook (Local)

Important: `helm/plane/values/dev.yaml` is not sufficient by itself for managed services.
CI injects runtime values for:

- `plane-ce.env.pgdb_remote_url`
- `plane-ce.env.remote_redis_url`
- `plane-ce.rabbitmq.external_rabbitmq_url`

For manual/local helm upgrades, add a second values file with these runtime URLs.

1. Create a local override from the example:

```bash
cp helm/plane/values/dev.runtime.example.yaml helm/plane/values/dev.runtime.local.yaml
```

2. Fill `helm/plane/values/dev.runtime.local.yaml` with real DB/Redis/RabbitMQ connection URLs.

3. Run helm upgrade with both files:

```bash
helm upgrade --install plane-dev helm/plane \
  --namespace plane-dev \
  --create-namespace \
  --values helm/plane/values/dev.yaml \
  --values helm/plane/values/dev.runtime.local.yaml \
  --set-string plane-ce.env.docstore_bucket="<docstore-bucket>" \
  --set-string plane-ce.env.aws_region="eu-west-1" \
  --set-string plane-ce.env.aws_s3_endpoint_url=""
```

Without the runtime override file, manual upgrades can fail due to empty managed-service URLs.

## Plane ALB Routing

Plane path routing is defined by the upstream `plane-ce` ingress template and is applied through this wrapper chart.

- `/` -> `plane-dev-web:3000`
- `/api` -> `plane-dev-api:8000`
- `/auth` -> `plane-dev-api:8000`
- `/live/` -> `plane-dev-live:3000`
- `/spaces` -> `plane-dev-space:3000`
- `/god-mode` -> `plane-dev-admin:3000`

`aws-load-balancer-controller` is installed by the production workflow and ingress class is set to `alb` in `helm/plane/values/dev.yaml`.

## Plane CE CSV Import (API Script)

Plane Community Edition does not provide the built-in CSV importer UI.  
Use the script below to import CSV rows via Plane API:

- Script: `scripts/import-plane-csv.py`
- Runtime: Python 3.x (no external pip dependency)

1. Export required environment variables

```bash
export PLANE_BASE_URL="http://<your-plane-url>"
export PLANE_WORKSPACE_SLUG="<workspace-slug>"
export PLANE_API_KEY="<plane-api-key>"
```

2. Run a dry-run first

```bash
python3 scripts/import-plane-csv.py \
  --csv ./issues.csv \
  --project-identifier <project-key> \
  --dry-run
```

3. Import for real

```bash
python3 scripts/import-plane-csv.py \
  --csv ./issues.csv \
  --project-identifier <project-key> \
  --create-missing-labels \
  --skip-errors
```

Supported CSV columns:

- Required: `name` (or `title`)
- Optional: `description`, `description_html`, `priority`, `state`, `state_id`
- Optional: `labels`, `label_ids`, `assignees`, `assignee_ids`
- Optional: `estimate_point`, `start_date`, `target_date`, `type`, `module`, `parent`

Notes:

- Multi-value fields (`labels`, `assignees`, etc.) can use `;`, `,`, or `|` separators.
- `assignees` resolves by member email/display name.
- `state` and `labels` resolve by name.  
  If you use `--create-missing-labels`, missing labels are created automatically.

## Bootstrap First (Best Practice)

For a fresh AWS account, run bootstrap once before prod:

1. Run workflow `.github/workflows/terraform-bootstrap.yml` with `action=apply`
2. This creates:
   - S3 state bucket: `plane-cloud-platform-tfstate-<account-id>`
   - DynamoDB lock table: `plane-cloud-platform-tf-locks`
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

- Backend bucket pattern: `plane-cloud-platform-tfstate-<account-id>`
- Lock table: `plane-cloud-platform-tf-locks`

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

```bash
aws iam put-role-policy \
  --role-name github-actions-terraform-prod \
  --policy-name terraform-prod-policy \
  --policy-document file://.github/iam/terraform-prod-policy.json \
  --profile personal
```

Verify:

```powershell
aws iam get-role-policy `
  --role-name github-actions-terraform-prod `
  --policy-name terraform-prod-policy `
  --profile personal
```

```bash
aws iam get-role-policy \
  --role-name github-actions-terraform-prod \
  --policy-name terraform-prod-policy \
  --profile personal
```

When to run this:

- After any change to `.github/iam/terraform-prod-policy.json`
- Before re-running failing workflows caused by missing IAM permissions

## Future roadmap

Planned additions include:

- Argo CD for GitOps-based continuous delivery as a later-stage platform improvement, with separate applications for platform add-ons and Plane
- External Secrets Operator (ESO) to sync AWS Secrets Manager values into Kubernetes instead of generating runtime values in CI
- A staging environment and promotion flow (`dev` -> `staging` -> `prod`)
- Renovate for Terraform provider, Helm chart, and GitHub Actions update automation
- Near-term preference: use Renovate first for Plane version detection and update PRs before introducing GitOps complexity
- Reproducible Helm dependency management with pinned chart versions and lock-file based installs
- Automated, low-downtime Plane rollouts as Helm chart updates are published and promoted through controlled environments

## Notes

- Use the correct AWS profile/account before running Terraform.
- Run `terraform plan` before `terraform apply` for safer changes.

## Zero-to-Deploy Guide

Use this checklist to bring up the project from scratch in a new AWS account.

1. Create GitHub repository secrets
   - Add `AWS_GITHUB_OIDC_ROLE_ARN` in repository secrets.
   - Add optional `PLANE_S3_ENDPOINT_URL` (leave empty for AWS S3).

2. Configure AWS IAM/OIDC once (manual)
   - Create GitHub OIDC identity provider (`token.actions.githubusercontent.com`) if missing.
   - Create role `github-actions-terraform-prod` with trust policy for your repo/branch.
   - Attach inline policy from `.github/iam/terraform-prod-policy.json`.
   - Optional one-time bootstrap script:
     - `chmod +x scripts/bootstrap-oidc.sh`
     - `./scripts/bootstrap-oidc.sh --repo <OWNER/REPO> --branch main --profile personal`
   - Sync policy with:
     ```powershell
     aws iam put-role-policy `
       --role-name github-actions-terraform-prod `
       --policy-name terraform-prod-policy `
       --policy-document file://.github/iam/terraform-prod-policy.json `
       --profile personal
     ```
     ```bash
     aws iam put-role-policy \
       --role-name github-actions-terraform-prod \
       --policy-name terraform-prod-policy \
       --policy-document file://.github/iam/terraform-prod-policy.json \
       --profile personal
     ```

3. Run bootstrap once (manual trigger in GitHub Actions)
   - Open workflow `Terraform Bootstrap`.
   - Run with `action=apply`.
   - This creates:
     - `plane-cloud-platform-tfstate-<account-id>` (S3 backend bucket)
     - `plane-cloud-platform-tf-locks` (DynamoDB lock table)

4. Run production workflow
   - Open workflow `Terraform Prod`.
   - Run `action=apply` (or push to `main` after PR flow).
   - Pipeline order:
     - Terraform init/validate/plan
     - Terraform apply
     - Helm upgrade/install for Plane (`--rollback-on-failure --wait --wait-for-jobs`) with Terraform outputs injected as Helm values

5. Verify cluster and app
   - `kubectl get pods -n plane-dev`
   - `kubectl get jobs -n plane-dev`
   - `kubectl get pvc -n plane-dev`
   - Ensure migration job is `Complete`, core pods are `Running/Ready`, PVCs are `Bound`.

6. Post-setup hardening (recommended)
   - Restrict Plane IRSA role policy to exact bucket/prefix needs.
   - Add secret rotation and operational runbook for S3/DB recovery.

## Next Steps

To move this repository closer to production-grade best practices, implement the following in order:

1. IAM least-privilege refinement
   - Reduce broad permissions in `.github/iam/terraform-prod-policy.json`.
   - Scope S3, IAM, EKS, and RDS actions to exact required resources and operations.
   - Constrain `iam:PassRole` with explicit role ARNs and `iam:PassedToService`.

2. Secret management hardening
   - Keep runtime secrets in AWS Secrets Manager and remove CI-generated temporary runtime values files.
   - Add External Secrets Operator (ESO) so Kubernetes secrets are synced automatically.
   - Add secret rotation policy and runbook.

3. Managed data services migration
   - PostgreSQL: migrated to Amazon RDS PostgreSQL with CI-injected `pgdb_remote_url`.
   - RabbitMQ: migrated to Amazon MQ for RabbitMQ with CI-injected `external_rabbitmq_url`.
   - Redis: migrated to Amazon ElastiCache with CI-injected `remote_redis_url`.
   - Note: Amazon SQS is an option only with app-level queue integration changes; it is not a direct RabbitMQ drop-in.

4. DNS and TLS hardening
   - Attach a real domain (Route 53 or external registrar).
   - Use ACM certificates and enforce HTTPS redirects on ALB ingress.
   - Add ExternalDNS and tighten network/security group rules.

5. Observability, SLOs, and alerting
   - Add metrics/logging dashboards and alerts (CloudWatch and/or Prometheus/Grafana stack).
   - Track pod health, node pressure, API error rates, queue lag, and database availability.

6. Release safety controls
   - Enforce main branch protection with required checks and PR review.
   - Add post-deploy smoke tests in CI/CD.

7. Disaster recovery readiness
   - Document backup and restore runbooks for RDS and S3.
   - Run periodic recovery drills and validate RTO/RPO targets.

8. CI/CD pipeline optimization
   - Run Terraform and Helm conditionally using path filters (`terraform/**` vs `helm/**`) so unrelated changes do not trigger both stacks.
   - Split the current monolithic apply into focused jobs/workflows (`infra-apply`, `addons-deploy`, `app-deploy`) and execute only what changed.
   - Move cluster add-on upgrades (metrics-server, aws-load-balancer-controller, cluster-autoscaler) to a separate workflow or run them only when add-on inputs change.
   - Skip Terraform apply when plan has no changes.
   - Use `helm diff upgrade` and skip Helm upgrade when rendered manifests are unchanged.
   - Replace `helm dependency update` in CI with lock-file based dependency resolution (`Chart.lock` + `helm dependency build`) for faster and reproducible runs.
   - Add caching for Terraform providers and Helm cache directories.
   - Restart Plane workloads only when the service account annotation actually changes, instead of restarting on every deployment.
   - Improve workflow concurrency (for example `cancel-in-progress: true` on PR workflows) to avoid wasted runner time.

9. Network cost optimization with VPC endpoints
   - Evaluate whether NAT gateways can be removed entirely for private workloads.
   - Add the required VPC endpoints for AWS services used from private subnets, such as S3, ECR (`api` and `dkr`), STS, CloudWatch Logs, and Secrets Manager.
   - Keep private node and pod traffic on AWS backbone where possible, reduce NAT data processing charges, and document which endpoints are mandatory before disabling NAT.

10. GitOps adoption with Argo CD
   - Bootstrap Argo CD after cluster creation and keep its base installation declarative.
   - Model separate Argo CD applications for cluster add-ons and the Plane application.
   - Let GitHub Actions focus on validation, plan output, and policy checks while Argo CD owns in-cluster reconciliation.
   - Treat this as a later optimization; for simple upstream Plane version awareness and upgrade PRs, Renovate is sufficient in the near term.

11. Environment strategy and promotion flow
   - Add a staging environment that mirrors production structure with lower-cost sizing defaults.
   - Promote chart and configuration changes through `dev` -> `staging` -> `prod` instead of deploying directly to production first.
   - Separate environment-specific Terraform roots, Helm values, and runtime secret mappings more explicitly.

12. Deployment reproducibility and upgrade safety
   - Pin wrapper chart dependency versions instead of relying on `version: "*"` in `helm/plane/Chart.yaml`.
   - Use `helm dependency build` from `Chart.lock` in CI for deterministic installs.
   - Add `helm diff` and optional progressive rollout strategies for safer upgrades.

13. Policy and security automation
   - Add Terraform/Helm security checks such as `tfsec`, `checkov`, `trivy`, and secret scanning in CI.
   - Enforce policy-as-code rules for public endpoints, encryption, tags, backup retention, and deletion protection.
   - Consider cluster policy enforcement with Kyverno or Gatekeeper as the platform footprint grows.

14. Workload resilience and scaling maturity
   - Add PodDisruptionBudgets, topology spread constraints, and rollout safety settings for critical Plane workloads.
   - Evaluate Karpenter or mixed on-demand/spot worker strategies once workload behavior is better understood.
   - Tune HPA thresholds and resource requests from observed production metrics instead of static bootstrap defaults.

15. Cost visibility and governance
   - Add AWS Budgets and Cost Anomaly Detection for the account or project tags.
   - Review retention and lifecycle settings for backups, logs, and object storage to control long-term cost.
   - Document expected monthly cost envelopes per environment and revisit expensive defaults regularly.

