# Existing EKS Cluster Mode

By default, this kit creates a dedicated EKS cluster for Plane. That is the cleanest separation-of-concerns path and remains the backward-compatible default.

Set `CREATE_EKS_CLUSTER=false` when an organization already has a platform EKS cluster and wants to deploy Plane into a separate namespace instead of paying for another EKS control plane.

## What Changes

When `CREATE_EKS_CLUSTER=false`:

- Terraform does not create the VPC module.
- Terraform does not create the EKS cluster, managed node group, EBS CSI addon, or EKS cluster add-on IRSA roles.
- The production workflow does not install or update Cluster Autoscaler.
- The production workflow does not install or update AWS Load Balancer Controller by default.
- The Helm release does not create the wrapper `StorageClass` by default.
- The workflow does not create the Kubernetes namespace by default.
- Plane is still installed by Helm into `K8S_NAMESPACE`.
- AWS-managed data services can still be created, but they use the supplied existing VPC and private subnets.

This keeps ownership of the shared cluster, autoscaling layer, Karpenter, node groups, and cluster-level controllers with the platform team.

## Required Repository Variables

Set these GitHub repository variables:

| Variable | Required when | Example |
| --- | --- | --- |
| `CREATE_EKS_CLUSTER` | Existing cluster mode | `false` |
| `EXISTING_EKS_CLUSTER_NAME` | Existing cluster mode | `company-prod` |
| `EXISTING_VPC_ID` | Any of PostgreSQL, Redis, or RabbitMQ is `aws-managed` | `vpc-0123456789abcdef0` |
| `EXISTING_PRIVATE_SUBNET_IDS_JSON` | Any of PostgreSQL, Redis, or RabbitMQ is `aws-managed` | `["subnet-aaa","subnet-bbb","subnet-ccc"]` |
| `EXISTING_VPC_CIDR` | AWS-managed data services use default allowed CIDR blocks | `10.20.0.0/16` |
| `EXISTING_EKS_OIDC_PROVIDER_ARN` | Optional override for `OBJECT_STORE_MODE=s3-managed` | `arn:aws:iam::123456789012:oidc-provider/oidc.eks.eu-west-1.amazonaws.com/id/EXAMPLE` |

For `OBJECT_STORE_MODE=s3-managed`, the existing cluster must already have an IAM OIDC provider associated for IRSA. Terraform derives the expected provider ARN from the cluster OIDC issuer and AWS account when `EXISTING_EKS_OIDC_PROVIDER_ARN` is empty.

The AWS role in `AWS_GITHUB_OIDC_ROLE_ARN` must also be authorized inside the existing Kubernetes cluster. At minimum, it needs enough Kubernetes RBAC to install or upgrade the Plane Helm release in `K8S_NAMESPACE`, create/update the Plane service account, and manage the namespace-scoped objects rendered by the chart.

## Add-On Ownership

These variables default to `auto`:

| Variable | Dedicated cluster default | Existing cluster default |
| --- | --- | --- |
| `INSTALL_METRICS_SERVER` | Installed | Not installed unless set to `true` |
| `INSTALL_AWS_LOAD_BALANCER_CONTROLLER` | Installed | Not managed by this workflow |
| `INSTALL_CLUSTER_AUTOSCALER` | Installed | Not managed by this workflow |
| `CREATE_K8S_NAMESPACE` | Created if missing | Not created unless set to `true` |
| `CREATE_STORAGE_CLASS` | Created | Not created unless set to `true` |
| `STORAGE_CLASS_NAME` | `gp3-csi` | Name to use if `CREATE_STORAGE_CLASS=true` |
| `PLANE_STORAGE_CLASS_NAME` | Uses `STORAGE_CLASS_NAME` when this kit creates it | Existing StorageClass name for in-cluster service PVCs |

In existing cluster mode, the platform cluster should already provide the ingress controller and autoscaling stack it wants to use. The chart defaults to an `alb` IngressClass, so an existing AWS Load Balancer Controller installation is the lowest-friction path.

Set `INGRESS_CLASS_NAME` if the existing cluster uses a different ingress class. Set `INGRESS_ENABLED=false` if ingress is managed separately.

If you enable any in-cluster service mode on an existing cluster, either make sure the cluster has a default StorageClass or set `PLANE_STORAGE_CLASS_NAME` to an existing StorageClass.

## Example: Reuse Existing EKS With AWS-Managed Data Services

Repository variables:

```text
CREATE_EKS_CLUSTER=false
EXISTING_EKS_CLUSTER_NAME=company-prod
EXISTING_VPC_ID=vpc-0123456789abcdef0
EXISTING_PRIVATE_SUBNET_IDS_JSON=["subnet-aaa","subnet-bbb","subnet-ccc"]
EXISTING_VPC_CIDR=10.20.0.0/16
K8S_NAMESPACE=plane
```

Keep the service mode defaults:

```text
POSTGRES_MODE=aws-managed
REDIS_MODE=aws-managed
RABBITMQ_MODE=aws-managed
OBJECT_STORE_MODE=s3-managed
```

This creates RDS, ElastiCache, Amazon MQ, S3, Secrets Manager entries, and the Plane IRSA role, then installs Plane into the existing EKS cluster.

Before running `Terraform Prod`, make sure the `plane` namespace exists or set `CREATE_K8S_NAMESPACE=true` and grant the GitHub OIDC role permission to create namespaces.

## Example: Namespace-Only Application Deploy

If the organization already owns the databases, Redis, RabbitMQ, object storage, ingress controller, and autoscaling, use external service modes:

```text
CREATE_EKS_CLUSTER=false
EXISTING_EKS_CLUSTER_NAME=company-prod
K8S_NAMESPACE=plane
POSTGRES_MODE=external
REDIS_MODE=external
RABBITMQ_MODE=external
OBJECT_STORE_MODE=external-s3
INGRESS_CLASS_NAME=alb
```

Then set the external service secrets documented in [service-modes.md](service-modes.md).
