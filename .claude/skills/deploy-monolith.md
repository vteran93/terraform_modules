# EC2 Monolith Deploy

Skill para desplegar un nuevo proyecto usando la arquitectura EC2 monolito con docker-compose.

## Uso
```
/deploy-monolith <app_name> <subdomain>
```

Ejemplo: `/deploy-monolith paygate paygate.growthguard.io`

## Arquitectura

```
EC2 Graviton (ARM64) + Elastic IP
├── docker-compose (todo en una instancia)
│   ├── App container(s)
│   ├── PostgreSQL 16
│   └── Redis 7
├── EBS volume (/data) — datos persistentes
│   └── Docker data-root → /data/docker
│       ├── postgres_data (named volume)
│       └── redis_data (named volume)
└── DNS: <app>.growthguard.io
    └── Route53 zone ← NS delegation from Lightsail
```

## Flujo de deploy (3 pasos, sin excepciones)

1. Commit a master/main
2. GitHub Actions ejecuta `terraform apply -auto-approve`
3. Tests end-to-end con live providers

## Principios

- TODO es IaC. Cero pasos manuales post-apply.
- Monolito: DB y Redis dentro de la misma EC2, no RDS externo.
- EBS dedicado para datos: `prevent_destroy = true`. Sobrevive recreaciones de instancia.
- Elastic IP: el DNS A record sobrevive reinicios/reemplazos de EC2.
- OIDC: GitHub Actions usa `aws-actions/configure-aws-credentials` con role assumption. Sin access keys.
- Secretos via `TF_VAR_*` desde GitHub Secrets. Nunca en tfvars commiteados.

## Terraform Module

Fuente: `git::git@github.com:vteran93/terraform_modules.git//ec2-monolith?ref=main`

### Que crea el modulo
| Recurso | Proposito |
|---|---|
| ECR repository + lifecycle | Registry para imagen Docker ARM64 |
| IAM role + instance profile | SSM access + ECR pull |
| Security Group | 80, 443 + puertos de app configurables |
| EC2 Graviton | Instancia ARM64 con user-data bootstrap |
| EBS volume + attachment | Persistencia de datos Docker en /data |
| Elastic IP + association | IP publica fija |
| Route53 hosted zone + A record | DNS para el subdominio |
| Lightsail NS delegation (x4) | Delegacion desde growthguard.io |

### Variables requeridas del modulo
```hcl
app_name               = "my-app"
domain_name            = "myapp.growthguard.io"
vpc_id                 = "vpc-..."
subnet_id              = "subnet-..."
docker_compose_content = local.docker_compose  # templatefile output
```

## Para crear un nuevo proyecto

### 1. Estructura del directorio
```
my-new-app/
  infra/terraform/
    main.tf                  # Provider + module "app" call
    variables.tf             # App-specific vars (db creds, API keys)
    outputs.tf               # Proxy outputs from module
    backend.tf               # S3 backend (use -backend-config)
    docker-compose.prod.yml  # App-specific compose template
    terraform.tfvars.example # Valores no-sensibles de referencia
  .github/workflows/
    deploy.yml               # Calls reusable workflows from terraform_modules
  Dockerfile                 # Multi-stage, ARM64 compatible
```

### 2. main.tf minimo
```hcl
terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
  }
}

provider "aws" {
  region = var.aws_region
  default_tags {
    tags = {
      Project     = var.app_name
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}

locals {
  docker_compose = templatefile("${path.module}/docker-compose.prod.yml", {
    ecr_url     = module.app.ecr_repository_url
    image_tag   = var.ecr_image_tag
    db_name     = var.db_name
    db_user     = var.db_user
    db_password = var.db_password
    secret_key  = var.secret_key
    environment = var.environment
    # ... mas vars especificas de la app
  })
}

module "app" {
  source = "git::git@github.com:vteran93/terraform_modules.git//ec2-monolith?ref=main"

  app_name               = var.app_name
  environment            = var.environment
  aws_region             = var.aws_region
  instance_type          = var.instance_type
  vpc_id                 = var.vpc_id
  subnet_id              = var.subnet_id
  domain_name            = var.domain_name
  parent_domain_name     = var.parent_domain_name
  docker_compose_content = local.docker_compose
}
```

### 3. deploy.yml minimo
```yaml
name: Deploy
on:
  push:
    branches: ["master"]

permissions:
  id-token: write
  contents: read

jobs:
  terraform:
    uses: vteran93/terraform_modules/.github/workflows/terraform-apply.yml@main
    with:
      terraform_dir: infra/terraform
      backend_bucket: pc-growthguard-terraform-states
      backend_key: <app-name>/infra/terraform.tfstate
      backend_dynamodb_table: growthguard-terraform-lock
    secrets:
      aws_deploy_role_arn: ${{ secrets.AWS_DEPLOY_ROLE_ARN }}
      tf_vars: |
        TF_VAR_db_password=${{ secrets.TF_VAR_DB_PASSWORD }}
        TF_VAR_secret_key=${{ secrets.TF_VAR_SECRET_KEY }}

  build:
    needs: [terraform]
    uses: vteran93/terraform_modules/.github/workflows/build-push-ecr.yml@main
    with:
      ecr_repository_name: ${{ needs.terraform.outputs.ecr_repository_name }}
    secrets:
      aws_deploy_role_arn: ${{ secrets.AWS_DEPLOY_ROLE_ARN }}

  deploy:
    needs: [terraform, build]
    uses: vteran93/terraform_modules/.github/workflows/deploy-ssm.yml@main
    with:
      instance_id: ${{ needs.terraform.outputs.instance_id }}
      ecr_image_uri: ${{ needs.build.outputs.full_image_uri }}
      app_name: <app-name>
    secrets:
      aws_deploy_role_arn: ${{ secrets.AWS_DEPLOY_ROLE_ARN }}
```

### 4. GitHub Secrets necesarios
| Secret | Descripcion |
|---|---|
| `AWS_DEPLOY_ROLE_ARN` | `arn:aws:iam::992382565701:role/github-deployment-role` |
| `TF_VAR_DB_PASSWORD` | Password PostgreSQL |
| `TF_VAR_SECRET_KEY` | App secret key |
| Otros `TF_VAR_*` | Variables sensibles especificas de la app |

### 5. Agregar repo al trust policy del IAM role
En `growthguard-glue-jobs/terraform/bootstrap/main.tf`, agregar el nuevo repo al OIDC trust:
```
repo:org/new-repo:ref:refs/heads/master
```

### 6. Backend state key
Cada proyecto usa un key unico en el mismo bucket:
```
bucket: pc-growthguard-terraform-states
key:    <app-name>/infra/terraform.tfstate
table:  growthguard-terraform-lock
```

## Infraestructura compartida (ya existe)

| Recurso | Valor | Donde |
|---|---|---|
| VPC | `vpc-093b8ac39459fd4da` | growthguard-glue-jobs |
| Public subnet (us-east-1a) | `subnet-085d4fd9194ebb0c2` | growthguard-glue-jobs |
| OIDC Provider | GitHub Actions | bootstrap/main.tf |
| IAM Role | `github-deployment-role` | bootstrap/main.tf |
| S3 state bucket | `pc-growthguard-terraform-states` | bootstrap/main.tf |
| DynamoDB lock table | `growthguard-terraform-lock` | bootstrap/main.tf |
| Parent DNS | `growthguard.io` en Lightsail | Lightsail console |

## Costos por instancia

| Recurso | Costo/mes |
|---|---|
| EC2 t4g.medium | ~$24.40 |
| EBS 30 GB gp3 | ~$2.40 |
| Elastic IP (asociada) | $0.00 |
| Route53 hosted zone | $0.50 |
| ECR storage | ~$0.10/GB |
| **Total** | **~$28/mes** |
