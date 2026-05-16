# Terraform AWS Web Infrastructure

Infrastructure as Code (IaC) for a 3-tier web architecture on AWS using Terraform.

## Architecture

```
                           Internet
                              |
                      [ Internet Gateway ]
                              |
         +--------------------+--------------------+
         |          VPC  10.0.0.0/16               |
         |                                         |
         |   AZ-a                  AZ-b            |
         |  +-----------+        +-----------+     |
         |  | Subred    |        | Subred    |     |  <- Subredes PÚBLICAS
         |  | pública   |        | pública   |     |     (ALB + NAT Gateway)
         |  |  [ ALB ]  |        |  [ ALB ]  |     |
         |  +-----+-----+        +-----+-----+     |
         |        |                    |          |
         |  +-----v-----+        +-----v-----+     |
         |  | Subred    |        | Subred    |     |  <- Subredes PRIVADAS
         |  | privada   |        | privada   |     |     (EC2 en Auto Scaling Group)
         |  | [ EC2 ]   |        | [ EC2 ]   |     |
         |  +-----+-----+        +-----+-----+     |
         |        |                    |          |
         |  +-----v-----+        +-----v-----+     |
         |  | Subred    |        | Subred    |     |  <- Subredes BBDD (aisladas)
         |  | BBDD      |        | BBDD      |     |     (RDS Multi-AZ en prod)
         |  +-----------+        +-----------+     |
         +-----------------------------------------+

         [ S3 Bucket ]  <- almacenamiento de objetos (assets / logs)
```

**Flujo de tráfico:**

1. El tráfico entrante llega al **Application Load Balancer** en las subredes públicas.
2. El ALB reparte la carga entre las instancias **EC2** del **Auto Scaling Group** ubicadas en las subredes privadas.
3. Las instancias acceden a **RDS** en las subredes de base de datos, aisladas y sin salida a internet.
4. Las instancias obtienen salida a internet a través del **NAT Gateway**.
5. **S3** proporciona almacenamiento de objetos para activos estáticos y logs.

## Stack y requisitos previos

- **Terraform** >= 1.7
- **AWS Provider** ~> 5.x
- **Región**: eu-west-1 (por defecto)
- **terraform-docs** — documentación de módulos
- **tflint** — linting de Terraform
- **Docker** (opcional, para ejecución de Terraform vía imagen `hashicorp/terraform`)

### Prerrequisitos

- AWS CLI configurado con credenciales adecuadas
- Cuenta AWS con permisos para crear VPC, EC2, RDS, S3, IAM, DynamoDB
- Docker (si se usa el Makefile con contenedores)

## Estructura del repositorio

```
terraform-aws-web-infra/
├── README.md
├── PRD-terraform-aws-infra.md
├── .gitignore
├── .terraform-docs.yml
├── .tflint.hcl
├── Makefile
├── versions.tf
├── .github/
│   └── workflows/
│       └── ci.yml                  # Pipeline de CI (fmt, validate, lint, security)
├── docs/
│   ├── ARCHITECTURE.md             # Descripción detallada de la arquitectura
│   └── COSTS.md                    # Estimación de costes por entorno
├── scripts/
│   ├── bootstrap-backend.sh        # Crea bucket S3 + tabla DynamoDB del estado
│   └── gen-docs.sh                 # Ejecuta terraform-docs en todos los módulos
├── modules/
│   ├── networking/                 # VPC, subredes, gateways, routing
│   ├── security/                   # Security Groups (ALB, App, DB)
│   ├── compute/                    # ALB, ASG, Launch Template, IAM
│   ├── database/                   # RDS + Secrets Manager
│   └── storage/                    # S3 bucket (endurecido)
└── environments/
    ├── dev/                        # Entorno de desarrollo
    ├── staging/                    # Entorno de staging
    └── prod/                       # Entorno de producción
```

## Guía de despliegue

### Paso 1: Configurar credenciales de AWS

```bash
# Opción A: AWS CLI configurado
aws configure

# Opción B: Variables de entorno
export AWS_ACCESS_KEY_ID="your-access-key"
export AWS_SECRET_ACCESS_KEY="your-secret-key"
export AWS_DEFAULT_REGION="eu-west-1"
```

### Paso 2: Crear el backend remoto

Ejecutar el script de bootstrap **una sola vez** antes del primer `terraform init`:

```bash
./scripts/bootstrap-backend.sh
```

Este script crea:
- Un bucket S3 versionado y cifrado para almacenar el estado
- Una tabla DynamoDB para el bloqueo de estado (evita escrituras concurrentes)

> El script es idempotente: si el bucket y la tabla ya existen, no produce error.

### Paso 3: Configurar el backend

Editar `environments/dev/backend.tf` y reemplazar los placeholders:
- `bucket` — nombre del bucket S3 creado en el paso 2
- `dynamodb_table` — nombre de la tabla DynamoDB creada en el paso 2

Repetir para `staging` y `prod`.

### Paso 4: Desplegar el entorno

```bash
# Inicializar Terraform
cd environments/dev
terraform init

# Revisar el plan
terraform plan

# Aplicar los cambios
terraform apply
```

### Paso 5: Verificar el despliegue

Tras el `apply`, los outputs muestran información clave:

```bash
# El DNS del ALB (punto de entrada de la aplicación)
terraform output alb_dns_name

# El ARN del secreto de la base de datos
terraform output db_secret_arn
```

Acceder al DNS del ALB en un navegador para verificar que nginx responde correctamente.

### Desplegar staging y prod

```bash
cd environments/staging && terraform init && terraform plan && terraform apply
cd environments/prod    && terraform init && terraform plan && terraform apply
```

## Destrucción de entornos

> **Atención:** `terraform destroy` elimina **todos** los recursos del entorno.
> Esta acción es **irreversible**. Asegurarse de tener backups antes de destruir.

```bash
cd environments/dev
terraform destroy
```

### Aviso sobre costes

Los recursos **NAT Gateway** y **Application Load Balancer** se facturan por hora,
incluso sin tráfico (~16-35 USD/mes cada uno). Si no se va a usar un entorno
durante un periodo prolongado, ejecutar `terraform destroy` para evitar costes innecesarios.

Consultar [docs/COSTS.md](docs/COSTS.md) para estimaciones detalladas por entorno.

## Documentación adicional

- [Arquitectura](docs/ARCHITECTURE.md) — Descripción detallada, decisiones de diseño y trade-offs
- [Costes estimados](docs/COSTS.md) — Estimación mensual por recurso y por entorno
- [Documentación de módulos](modules/) — Cada módulo tiene su propio README con inputs, outputs y recursos

## Decisiones de diseño y trade-offs

| Decisión | Razón | Trade-off |
|----------|-------|-----------|
| 3 niveles de subredes | Aislamiento de seguridad entre capas | Mayor complejidad de red |
| Single NAT en dev/staging | Reduce coste (~33 USD/mes por NAT) | Punto único de fallo fuera de prod |
| Multi-AZ RDS solo en prod | Alta disponibilidad donde importa | Coste duplicado de RDS |
| Security groups por ID | Funciona con IPs dinámicas del ASG | Reglas más complejas de auditar |
| Contraseña autogenerada | Sin secretos en el repositorio | Requiere acceso a Secrets Manager |
| Estado remoto con lock | Trabajo en equipo sin conflictos | Dependencia de S3 + DynamoDB |

## Alcance

### Incluido en esta fase

- Arquitectura web de 3 niveles (ALB → EC2 → RDS) con módulos reutilizables
- 3 entornos (dev, staging, prod) con configuración específica por entorno
- Estado remoto en S3 con bloqueo en DynamoDB
- Security groups con aislamiento entre capas
- Bucket S3 endurecido con versionado y cifrado
- RDS con contraseña autogenerada y almacenamiento en Secrets Manager
- Auto Scaling Group con política de escalado por CPU
- Pipeline de CI con validación de formato, sintaxis, linting y seguridad
- Documentación de costes y arquitectura

### Fuera de alcance (fases posteriores)

- Terminación HTTPS en el ALB con certificado ACM y dominio en Route 53
- Pipeline de entrega: `terraform plan` automático en cada PR con `apply` manual
- Migración de EC2 + ASG a contenedores (ECS Fargate o EKS)
- Autenticación OIDC en el CI en lugar de claves de acceso estáticas
- Módulo de observabilidad: dashboards y alarmas en CloudWatch
- Pruebas automatizadas de infraestructura con Terratest

## Licencia

MIT
