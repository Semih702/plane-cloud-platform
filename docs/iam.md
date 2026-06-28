# IAM Model

GitHub Actions uses OpenID Connect to assume one short-lived AWS IAM role. The role is created by `scripts/bootstrap-oidc.sh` and receives `.github/iam/terraform-prod-policy.json` as an inline policy.

## Why The Policy Is Broad

The first deploy creates infrastructure across several AWS control planes:

- EC2 networking for VPCs, subnets, NAT gateways, security groups, route tables, and service-managed network interfaces
- EKS cluster, managed node group, access entries, and add-ons
- IAM roles, policies, OIDC providers, and service-linked roles
- RDS, Amazon MQ, ElastiCache, S3, DynamoDB, and Secrets Manager
- AWS Load Balancer Controller and Cluster Autoscaler IAM roles

Several AWS APIs require `Resource: "*"` for create, describe, tagging, service-linked-role, or dependent actions. The policy narrows the highest-risk operations where AWS supports it, including role name patterns, service-linked-role service names, Terraform tags, and `iam:PassedToService`.

## Trust Policy Scope

The OIDC trust policy should be scoped to one repository, branch, and the protected GitHub Environment used by apply jobs:

- `repo:<owner>/<repo>:ref:refs/heads/main`
- `repo:<owner>/<repo>:environment:prod`

The helper can also allow `pull_request`, but official upstream deployments should avoid AWS-authenticated work on public fork pull requests. This repository's `CI` workflow is secret-free; deployment workflows are manual.

## State And Secrets

Terraform-generated service credentials are stored in AWS Secrets Manager, then injected into Helm at deploy time. Terraform state may still contain sensitive generated values.

Keep the state backend:

- Private
- Encrypted
- Versioned
- Restricted to trusted administrators and the GitHub OIDC deploy role

## Operational Boundary

This kit is designed to create Plane infrastructure in one AWS account and region. It should not be attached to an unrestricted organization-wide admin role. If an organization adopts it, create a dedicated deployment role and review the inline policy against the services and modes it plans to support.
