# Service Modes

The default deployment uses AWS-managed dependencies. Advanced users can move one or more dependencies in-cluster or point Plane at existing external services.

Service modes are independent from cluster ownership. The default cluster path creates a dedicated EKS cluster; [existing-cluster mode](existing-cluster.md) deploys Plane into a supplied EKS cluster while keeping the same service-mode choices.

## Mode Variables

Set these as GitHub repository variables.

| Variable | Default | Allowed values |
| --- | --- | --- |
| `POSTGRES_MODE` | `aws-managed` | `aws-managed`, `in-cluster`, `external` |
| `REDIS_MODE` | `aws-managed` | `aws-managed`, `in-cluster`, `external` |
| `RABBITMQ_MODE` | `aws-managed` | `aws-managed`, `in-cluster`, `external` |
| `OBJECT_STORE_MODE` | `s3-managed` | `s3-managed`, `minio-in-cluster`, `external-s3` |

## AWS-Managed

This is the recommended first deploy path.

- `POSTGRES_MODE=aws-managed`: Terraform creates RDS PostgreSQL.
- `REDIS_MODE=aws-managed`: Terraform creates ElastiCache Redis.
- `RABBITMQ_MODE=aws-managed`: Terraform creates Amazon MQ for RabbitMQ.
- `OBJECT_STORE_MODE=s3-managed`: Terraform creates an S3 bucket and a Plane IRSA role.

No additional service connection secrets are required.

## In-Cluster

Use this for lower-cost test environments or when you want Kubernetes StatefulSets instead of AWS managed services.

- `POSTGRES_MODE=in-cluster`
- `REDIS_MODE=in-cluster`
- `RABBITMQ_MODE=in-cluster`
- `OBJECT_STORE_MODE=minio-in-cluster`

The workflow still creates EKS and stores generated runtime credentials in AWS Secrets Manager, but it does not create RDS, ElastiCache, Amazon MQ, or the Plane S3 bucket for the services switched to in-cluster mode.

If `CREATE_EKS_CLUSTER=false`, the workflow uses the existing EKS cluster instead of creating a new one.

In-cluster services need a working Kubernetes StorageClass. Dedicated-cluster mode uses `STORAGE_CLASS_NAME` with a default of `gp3-csi`; existing-cluster mode can use the cluster default StorageClass or an explicit `PLANE_STORAGE_CLASS_NAME`.

## External

Use this when you already run service dependencies elsewhere.

Set these repository secrets only for the external modes you enable:

| Mode | Required secret or variable |
| --- | --- |
| `POSTGRES_MODE=external` | secret `PLANE_PGDB_REMOTE_URL` |
| `REDIS_MODE=external` | secret `PLANE_REDIS_URL` |
| `RABBITMQ_MODE=external` | secret `PLANE_RABBITMQ_URL` |
| `OBJECT_STORE_MODE=external-s3` | variable `PLANE_DOCSTORE_BUCKET`, secrets `PLANE_EXTERNAL_S3_ACCESS_KEY_ID` and `PLANE_EXTERNAL_S3_SECRET_ACCESS_KEY` |

Optional external object-store settings:

- `PLANE_EXTERNAL_S3_REGION`: repository variable; defaults to `AWS_REGION`
- `PLANE_S3_ENDPOINT_URL`: repository secret for S3-compatible storage endpoints

## Choosing A Profile

- Use AWS-managed for the strongest one-person production-style deploy story.
- Use in-cluster for demos and low-cost experiments.
- Use external when an organization already owns databases, queues, Redis, or object storage.

Changing modes after the first deploy can replace or abandon managed resources. Always run `Terraform Prod` with `action=plan` first.
