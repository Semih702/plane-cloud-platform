# Plane AWS Deployment Kit

This repository is a fork-and-deploy kit for running Plane Community Edition on AWS with GitHub Actions, Terraform, and Helm.

The default path is intentionally simple:

1. Fork the repository.
2. Create one AWS IAM role trusted by GitHub OIDC.
3. Add that role ARN as `AWS_GITHUB_OIDC_ROLE_ARN`.
4. Run `Terraform Bootstrap` once.
5. Run `Terraform Prod` to create infrastructure and install Plane.

No long-lived AWS access keys are required for the default AWS-managed deployment.

## Default Architecture

Terraform creates:

- VPC, public/private subnets, NAT gateways, route tables, and Kubernetes subnet tags
- EKS cluster, managed node group, EBS CSI addon, and IRSA roles
- Optional AWS-managed Plane dependencies: RDS PostgreSQL, Amazon MQ RabbitMQ, ElastiCache Redis, and S3 docstore
- Secrets Manager entries for generated service credentials and Plane app secrets
- Terraform state backend resources through the bootstrap workflow

Helm installs:

- Plane CE through the wrapper chart in `helm/plane`
- A `gp3-csi` StorageClass
- AWS Load Balancer Controller-backed ALB ingress
- metrics-server and Cluster Autoscaler

This dedicated-cluster path is the default. Organizations that already have a platform EKS cluster can set `CREATE_EKS_CLUSTER=false` and deploy Plane into that cluster instead.

## Workflows

- `CI`: runs on pull requests and pushes to `main`; it does not request AWS credentials or GitHub secrets.
- `Terraform Bootstrap`: manual only; creates/imports the S3 state bucket and DynamoDB lock table.
- `Terraform Prod`: manual only; runs `plan` or `apply` for AWS infrastructure and the Plane Helm release.

This split keeps public fork PRs reviewable without exposing repository secrets.

## Required Secret

Create this GitHub repository secret after creating the AWS OIDC role:

- `AWS_GITHUB_OIDC_ROLE_ARN`: IAM role ARN assumed by GitHub Actions

## Common Variables

The defaults work for the standard AWS-managed path.

- `AWS_REGION`: default `eu-west-1`
- `PROJECT_NAME`: default `plane`
- `DEPLOY_ENVIRONMENT`: default `prod`
- `TF_STATE_BUCKET`: optional explicit Terraform state bucket
- `TF_STATE_BUCKET_PREFIX`: default `plane-cloud-platform-tfstate`
- `TF_STATE_KEY`: default `prod/terraform.tfstate`
- `TF_LOCK_TABLE_NAME`: default `plane-cloud-platform-tf-locks`
- `HELM_RELEASE_NAME`: default `plane`
- `K8S_NAMESPACE`: default `plane`
- `PLANE_APP_HOST`: optional custom host; when empty, the ALB DNS name is usable after deploy
- `CREATE_EKS_CLUSTER`: default `true`; set `false` to deploy into an existing EKS cluster
- `INGRESS_CLASS_NAME`: default `alb`
- `INGRESS_ENABLED`: default `true`
- `STORAGE_CLASS_NAME`: default `gp3-csi` when this kit creates the StorageClass
- `PLANE_STORAGE_CLASS_NAME`: optional existing StorageClass name for in-cluster service PVCs

## Existing EKS Cluster

Use existing-cluster mode when a company wants Plane in a separate namespace on an EKS cluster it already operates, avoiding the extra EKS control-plane cost and keeping cluster autoscaling ownership with the platform team.

Set these repository variables at minimum:

- `CREATE_EKS_CLUSTER=false`
- `EXISTING_EKS_CLUSTER_NAME=<cluster-name>`

If any data service remains AWS-managed, also set:

- `EXISTING_VPC_ID=<vpc-id>`
- `EXISTING_PRIVATE_SUBNET_IDS_JSON=["subnet-a","subnet-b","subnet-c"]`
- `EXISTING_VPC_CIDR=<vpc-cidr>`

The workflow does not install Cluster Autoscaler, AWS Load Balancer Controller, or the wrapper StorageClass in existing-cluster mode by default. The GitHub OIDC role must already have Kubernetes RBAC in the target cluster and namespace. Set `PLANE_STORAGE_CLASS_NAME` if in-cluster services should use a specific existing StorageClass. See [docs/existing-cluster.md](docs/existing-cluster.md).

## Service Modes

Each Plane dependency can be AWS-managed, in-cluster, or external.

- `POSTGRES_MODE`: `aws-managed`, `in-cluster`, or `external`
- `REDIS_MODE`: `aws-managed`, `in-cluster`, or `external`
- `RABBITMQ_MODE`: `aws-managed`, `in-cluster`, or `external`
- `OBJECT_STORE_MODE`: `s3-managed`, `minio-in-cluster`, or `external-s3`

See [docs/service-modes.md](docs/service-modes.md) for the required variables and secrets for each mode.

## Zero-To-Deploy

From a machine with AWS CLI admin access to your AWS account:

```bash
chmod +x scripts/bootstrap-oidc.sh
./scripts/bootstrap-oidc.sh --repo <OWNER>/<REPO> --branch main --profile <AWS_PROFILE>
```

Add the printed role ARN as `AWS_GITHUB_OIDC_ROLE_ARN`.
The helper trusts both the `main` branch and the `prod` GitHub Environment because apply jobs run through that protected environment.

Then run these GitHub Actions manually:

1. `Terraform Bootstrap` with `action=apply`
2. `Terraform Prod` with `action=plan`
3. `Terraform Prod` with `action=apply`

Approve the `prod` deployment prompt when GitHub pauses an apply job for environment review.

After deploy:

```bash
aws eks update-kubeconfig --name plane-prod-eks --region eu-west-1
kubectl get ingress plane-ingress -n plane
```

Open the ALB hostname unless you configured `PLANE_APP_HOST`.

## Security Notes

- GitHub uses OIDC to assume a short-lived AWS role.
- Database, RabbitMQ, Redis, MinIO, and Plane app secrets are generated by Terraform and stored in AWS Secrets Manager for workflow injection.
- Terraform state can contain generated secrets; keep the S3 backend private, encrypted, and access controlled.
- The production apply job uses the GitHub `prod` environment so repository owners can require manual approval.
- Do not add AWS access keys to GitHub for the default deployment path.

More detail:

- [docs/proposal-to-plane.md](docs/proposal-to-plane.md)
- [docs/existing-cluster.md](docs/existing-cluster.md)
- [docs/iam.md](docs/iam.md)
- [docs/runbook.md](docs/runbook.md)
- [.github/README-OIDC.md](.github/README-OIDC.md)

## Repository Layout

- `.github/workflows/ci.yml`: secret-free validation for PRs and pushes
- `.github/workflows/terraform-bootstrap.yml`: manual state backend workflow
- `.github/workflows/terraform-prod.yml`: manual plan/apply workflow
- `.github/iam/terraform-prod-policy.json`: IAM policy for the GitHub OIDC role
- `scripts/bootstrap-oidc.sh`: helper for creating/updating the OIDC role
- `terraform/environments/bootstrap`: S3 + DynamoDB backend bootstrap
- `terraform/environments/prod`: production Terraform root
- `terraform/modules`: reusable AWS modules
- `helm/plane`: Plane wrapper chart
