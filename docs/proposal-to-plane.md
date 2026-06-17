# Proposal: Plane AWS Deployment Kit

## Summary

We propose contributing this repository as a fork-and-deploy AWS deployment kit for Plane Community Edition.

The goal is to let one operator deploy Plane into their own AWS account using GitHub Actions, Terraform, and Helm with minimal manual work:

1. Fork the repository.
2. Create a GitHub OIDC IAM role in AWS.
3. Add one required GitHub secret: `AWS_GITHUB_OIDC_ROLE_ARN`.
4. Run the bootstrap workflow.
5. Run the production workflow.

The default path provisions AWS-managed infrastructure, while advanced users can switch individual dependencies to in-cluster or external services.

## Why This Helps Plane

Plane already has strong self-hosting interest. A maintained AWS deployment kit would reduce friction for teams that want a cloud-native installation but do not want to assemble EKS, RDS, Redis, RabbitMQ, S3, IRSA, ingress, and CI/CD wiring from scratch.

This kit is designed to be:

- Fork friendly: users can run it from their own GitHub repository and AWS account.
- Secret conscious: the default path uses GitHub OIDC, not long-lived AWS access keys.
- Reviewable: pull request CI is secret-free and deployment workflows are manual.
- Configurable: PostgreSQL, Redis, RabbitMQ, and object storage can be AWS-managed, in-cluster, or external.
- Operationally explicit: IAM, service modes, and runbook behavior are documented.

## What The Kit Deploys

By default, Terraform creates:

- VPC across multiple Availability Zones
- EKS cluster and managed node group
- EBS CSI addon and controller IRSA roles
- RDS PostgreSQL
- Amazon MQ for RabbitMQ
- ElastiCache Redis
- S3 document store bucket
- Secrets Manager entries for generated service credentials and Plane application secrets
- Terraform S3 backend and DynamoDB lock table through a separate bootstrap workflow

The production workflow then installs:

- metrics-server
- AWS Load Balancer Controller
- Cluster Autoscaler
- Plane CE through the wrapper Helm chart
- ALB ingress, with a hostless first-deploy option

## Configuration Model

The default deployment uses managed AWS services. Operators can override service modes with repository variables:

- `POSTGRES_MODE=aws-managed|in-cluster|external`
- `REDIS_MODE=aws-managed|in-cluster|external`
- `RABBITMQ_MODE=aws-managed|in-cluster|external`
- `OBJECT_STORE_MODE=s3-managed|minio-in-cluster|external-s3`

External modes read explicitly configured GitHub secrets for existing service URLs or S3-compatible credentials. In-cluster modes use generated credentials stored in AWS Secrets Manager and injected at deploy time.

## Security And Workflow Design

The repository separates validation from deployment:

- `CI` runs on pull requests and pushes without AWS credentials.
- `Terraform Bootstrap` is manual and creates/imports the remote state backend.
- `Terraform Prod` is manual and runs `plan` or `apply`.

The default OIDC trust policy is branch-scoped and does not trust public pull request subjects. Production apply uses a GitHub Environment named `prod`, so maintainers can require reviewer approval.

Terraform state may contain generated secrets, so the backend is private, encrypted, versioned, and intended to be accessed only by trusted administrators and the GitHub deployment role.

## Current Validation

The repository currently passes local static validation for:

- Terraform formatting
- Terraform validation for bootstrap and production roots
- Workflow YAML parsing
- IAM policy JSON parsing
- Helm lint
- Helm template rendering for AWS-managed, in-cluster, and external service profiles
- Secret and hardcoded account scans over tracked text files

The remaining validation needed before publishing as an official Plane-maintained option is a clean end-to-end AWS apply in a disposable AWS account, including teardown notes and cost/quota observations.

## Proposed Adoption Path

1. Plane maintainers review the architecture, IAM policy, workflow model, and Helm wrapper.
2. We run a clean end-to-end deployment in a fresh AWS account and share logs/screenshots.
3. Plane maintainers decide whether this should live as:
   - an official Plane repository,
   - a community-maintained repository under the Plane organization,
   - or a documented reference implementation linked from Plane self-hosting docs.
4. After review, we can tighten naming, defaults, IAM boundaries, and docs to match Plane's preferred maintenance standards.

## Review Questions For Plane

- Should this target Plane CE only, or leave room for other Plane editions later?
- Should AWS-managed remain the default profile?
- Are in-cluster dependency modes useful enough to keep in the first version?
- Should this repository vendor the Plane chart archive or rely only on `helm dependency build` from `Chart.lock`?
- What IAM boundary is acceptable for a first-deploy kit?
- Where should this live if accepted: Plane org, community examples, or self-hosting docs?

## Short Outreach Message

Hi Plane team,

I built a fork-and-deploy AWS deployment kit for Plane CE using GitHub Actions, Terraform, and Helm. The goal is to let one operator deploy Plane into their own AWS account with GitHub OIDC, a bootstrap workflow, and a manual production workflow.

The default profile provisions EKS, RDS PostgreSQL, Amazon MQ RabbitMQ, ElastiCache Redis, S3, IRSA roles, ALB ingress, and generated secrets. It also supports configurable service modes, so PostgreSQL, Redis, RabbitMQ, and object storage can be AWS-managed, in-cluster, or external.

I would like to propose this as a Plane-maintained or Plane-linked deployment kit for AWS self-hosting. The repository is structured so PR CI is secret-free, deploy workflows are manual, and IAM/service-mode/runbook documentation is included.

I would appreciate your review on whether this fits Plane's self-hosting direction and what changes would be required for it to become an official or community-supported deployment option.
