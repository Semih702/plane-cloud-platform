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

## Configuration model

The repository is designed to work without editing environment-specific values directly into workflow files.

Required GitHub secret:

- `AWS_GITHUB_OIDC_ROLE_ARN`: IAM role assumed by GitHub Actions through OIDC

Optional GitHub secrets:

- `PLANE_S3_ENDPOINT_URL`: only for custom S3-compatible endpoints; leave unset for AWS S3

Optional GitHub repository variables:

- `AWS_REGION`: defaults to `eu-west-1`
- `PROJECT_NAME`: defaults to `plane`
- `ENVIRONMENT_NAME`: defaults to `prod`
- `TF_STATE_BUCKET_PREFIX`: defaults to `plane-cloud-platform-tfstate`
- `TF_STATE_BUCKET`: exact backend bucket override; normally leave unset
- `TF_LOCK_TABLE`: defaults to `plane-cloud-platform-tf-locks`
- `TF_STATE_KEY`: defaults to `prod/terraform.tfstate`
- `HELM_RELEASE_NAME`: defaults to `<PROJECT_NAME>-<ENVIRONMENT_NAME>` (`plane-prod` with defaults)
- `K8S_NAMESPACE`: defaults to `<PROJECT_NAME>-<ENVIRONMENT_NAME>` (`plane-prod` with defaults)
- `HELM_VALUES_FILE`: defaults to `helm/plane/values/dev.yaml`
- `PLANE_APP_HOST`: optional custom domain for Plane

If `PLANE_APP_HOST` is unset, the production workflow deploys once with a temporary bootstrap host, reads the generated ALB DNS name, then runs a second Helm upgrade to use that ALB DNS name as Plane's app host. If you already have a real domain, set `PLANE_APP_HOST` before the first production apply and later point DNS at the ALB.

## Current AWS network design (implemented)

Default region: `eu-west-1` through `AWS_REGION`

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

## Availability and isolation

The production design is intentionally isolated and highly available at the platform layer:

- Plane runs on its own dedicated EKS cluster: `<PROJECT_NAME>-<ENVIRONMENT_NAME>-eks` (`plane-prod-eks` with defaults)
- EKS control plane and worker nodes use private subnets across 3 Availability Zones
- Public exposure is handled through ALB ingress; application workloads stay inside the cluster/VPC boundary
- One NAT Gateway per AZ avoids a single shared egress dependency for private workloads
- Cluster Autoscaler is installed with IRSA so the managed node group can scale between configured minimum and maximum capacity
- HPA rules are defined for core Plane workloads (`web`, `api`, `worker`, and `beatworker`) and use CPU utilization as the scaling signal

Current bootstrap sizing is intentionally conservative for cost control. Production replica counts, HPA max replicas, and node group limits should be raised based on observed metrics and expected traffic.

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
- CI derives the Plane service account and document-store secret names from `HELM_RELEASE_NAME`, and the wrapper chart creates the document-store secret during `helm upgrade/install`, so app deploy is self-contained.
- The S3 doc-store bucket has CORS enabled for browser-based presigned uploads.
- CI defaults `AWS_S3_ENDPOINT_URL` to the regional S3 endpoint (`https://s3.<AWS_REGION>.amazonaws.com`) to avoid global S3 endpoint redirects during uploads.

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

GitHub secrets used by the workflows:

- `AWS_GITHUB_OIDC_ROLE_ARN`
- `PLANE_S3_ENDPOINT_URL` (optional; when empty, CI uses `https://s3.<region>.amazonaws.com` for AWS S3)

## Unified Terraform + Helm Workflow

Deployment is handled in a single pipeline:

- Workflow file: `.github/workflows/terraform-prod.yml`
- PR: Terraform `init/validate/plan` + Helm `dependency update/lint/template`
- Main push or manual `apply`: Terraform apply first, then Helm upgrade with `--rollback-on-failure --wait --wait-for-jobs`
- Target cluster: `<PROJECT_NAME>-<ENVIRONMENT_NAME>-eks`
- Target namespace/release: `K8S_NAMESPACE` / `HELM_RELEASE_NAME`

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
helm upgrade --install <release-name> helm/plane \
  --namespace <namespace> \
  --create-namespace \
  --values helm/plane/values/dev.yaml \
  --values helm/plane/values/dev.runtime.local.yaml \
  --set-string plane-ce.external_secrets.doc_store_existingSecret="<release-name>-doc-store-secrets" \
  --set-string plane-ce.ingress.appHost="<plane-app-host>" \
  --set-string plane-ce.env.docstore_bucket="<docstore-bucket>" \
  --set-string plane-ce.env.aws_region="<aws-region>" \
  --set-string plane-ce.env.aws_s3_endpoint_url="https://s3.<aws-region>.amazonaws.com"
```

Without the runtime override file, manual upgrades can fail due to empty managed-service URLs.

## Plane ALB Routing

Plane path routing is defined by the upstream `plane-ce` ingress template and is applied through this wrapper chart. Service names are derived from `HELM_RELEASE_NAME`; examples below use the default release `plane-prod`.

- `/` -> `plane-prod-web:3000`
- `/api` -> `plane-prod-api:8000`
- `/auth` -> `plane-prod-api:8000`
- `/live/` -> `plane-prod-live:3000`
- `/spaces` -> `plane-prod-space:3000`
- `/god-mode` -> `plane-prod-admin:3000`

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
   - S3 state bucket: `<TF_STATE_BUCKET_PREFIX>-<account-id>` unless `TF_STATE_BUCKET` is set
   - DynamoDB lock table: `TF_LOCK_TABLE`
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

- Backend bucket pattern: `<TF_STATE_BUCKET_PREFIX>-<account-id>` unless `TF_STATE_BUCKET` is set
- Backend key: `TF_STATE_KEY`
- Lock table: `TF_LOCK_TABLE`

The `terraform/environments/prod` backend block is intentionally partial. GitHub Actions passes backend bucket, key, region, encryption, and lock-table values during `terraform init`. Bootstrap resources are managed by `terraform/environments/bootstrap` and should be applied once per AWS account through the bootstrap workflow.

For portability across fresh AWS accounts, the CI workflow also ensures
`AWSServiceRoleForRDS` exists before Terraform runs.

## IAM Policy Sync Guide (No Manual Copy/Paste)

Instead of pasting policy JSON in the AWS Console, sync the repo policy file directly with AWS CLI.

Prerequisites:

- AWS CLI installed
- An admin-capable profile
- Existing role name: `github-actions-terraform-prod`

Command:

```powershell
aws iam put-role-policy `
  --role-name github-actions-terraform-prod `
  --policy-name terraform-prod-policy `
  --policy-document file://.github/iam/terraform-prod-policy.json `
  --profile <profile>
```

```bash
aws iam put-role-policy \
  --role-name github-actions-terraform-prod \
  --policy-name terraform-prod-policy \
  --policy-document file://.github/iam/terraform-prod-policy.json \
  --profile <profile>
```

Verify:

```powershell
aws iam get-role-policy `
  --role-name github-actions-terraform-prod `
  --policy-name terraform-prod-policy `
  --profile <profile>
```

```bash
aws iam get-role-policy \
  --role-name github-actions-terraform-prod \
  --policy-name terraform-prod-policy \
  --profile <profile>
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

Use this sequence for a fresh AWS account. The production workflow depends on the remote Terraform backend, so the bootstrap workflow must succeed before any production plan/apply can run.

1. Log in to AWS locally with an admin-capable identity.

   ```bash
   aws login
   aws sts get-caller-identity
   ```

   With a named profile:

   ```bash
   aws sts get-caller-identity --profile <profile>
   ```

2. Create or update the GitHub OIDC role in AWS.

   ```bash
   chmod +x scripts/bootstrap-oidc.sh
   ./scripts/bootstrap-oidc.sh --repo <OWNER/REPO> --branch main --profile <profile>
   ```

   The script creates the GitHub OIDC provider if missing, creates or updates role `github-actions-terraform-prod`, and attaches `.github/iam/terraform-prod-policy.json`. Copy the printed role ARN.

3. Configure GitHub repository settings.

   Required secret:

   - `AWS_GITHUB_OIDC_ROLE_ARN` = role ARN printed by `scripts/bootstrap-oidc.sh`

   Optional variables:

   - Set `AWS_REGION`, `PROJECT_NAME`, `ENVIRONMENT_NAME`, `HELM_RELEASE_NAME`, and `K8S_NAMESPACE` only when you want values other than the defaults.
   - Set `PLANE_APP_HOST` if you have a real domain ready. Leave it unset to let CI adopt the generated ALB hostname automatically.
   - Leave `TF_STATE_BUCKET` unset unless you need an exact backend bucket name. The default is `<TF_STATE_BUCKET_PREFIX>-<account-id>`.

4. Run the backend bootstrap once.

   In GitHub Actions, open workflow `Terraform Bootstrap` and run it manually with `action=apply`.

   It creates:

   - S3 state bucket: `<TF_STATE_BUCKET_PREFIX>-<account-id>` unless `TF_STATE_BUCKET` is set
   - DynamoDB lock table: `TF_LOCK_TABLE`

5. Validate production after bootstrap.

   Open workflow `Terraform Prod` and run it manually with `action=plan`, or open a pull request that changes `terraform/**`, `helm/**`, or the workflow file. Before bootstrap exists, this plan cannot initialize the S3 backend.

6. Deploy production.

   Open workflow `Terraform Prod` and run it manually with `action=apply`, or merge a reviewed PR to `main`.

   The apply job does the following:

   - initializes Terraform with the bootstrapped S3/DynamoDB backend
   - creates VPC, EKS, RDS PostgreSQL, Amazon MQ RabbitMQ, ElastiCache Redis, S3 doc-store, and IAM/IRSA resources
   - installs cluster add-ons: metrics-server, AWS Load Balancer Controller, and Cluster Autoscaler
   - reads Terraform outputs and AWS Secrets Manager values
   - runs Helm upgrade/install for Plane with runtime DB/Redis/RabbitMQ/S3 values
   - if `PLANE_APP_HOST` is unset, reads the generated ALB hostname and runs a second Helm upgrade using that hostname
   - annotates the Plane service account with the S3 IRSA role and restarts Plane workloads

7. Verify the deployment.

   ```bash
   aws eks update-kubeconfig --name <PROJECT_NAME>-<ENVIRONMENT_NAME>-eks --region <AWS_REGION>
   kubectl get pods -n <K8S_NAMESPACE>
   kubectl get jobs -n <K8S_NAMESPACE>
   kubectl get ingress -n <K8S_NAMESPACE>
   ```

   Ensure the migration job is `Complete`, core pods are `Running/Ready`, and the ingress has an ALB hostname.

8. If you later attach a real domain, set `PLANE_APP_HOST` in GitHub repository variables and rerun `Terraform Prod` with `action=apply`. Then point your DNS record at the ALB hostname shown by the ingress.

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

