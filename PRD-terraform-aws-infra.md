# PRD — Infraestructura base de la plataforma web en AWS

> **Estado:** Borrador para revisión
> **Versión:** 1.0
> **Autor:** Equipo de Plataforma / Infraestructura
> **Última actualización:** mayo 2026

---

## 1. Contexto y motivación

La plataforma web necesita una base de infraestructura en AWS gestionada como código.
Actualmente no existe una definición versionada y reproducible del entorno, lo que
provoca configuraciones divergentes, despliegues manuales propensos a error y falta de
trazabilidad de los cambios.

Este documento define los requisitos de un repositorio de **Infraestructura como Código
(IaC)** con Terraform que proporcione una arquitectura web estándar, multi-entorno y
reproducible, sobre la que el equipo de aplicación pueda desplegar el servicio.

**Problemas que resuelve:**

- Eliminar la configuración manual de red, cómputo y base de datos.
- Garantizar que `dev`, `staging` y `prod` parten de la misma definición.
- Hacer auditable y revisable cada cambio de infraestructura vía control de versiones.
- Documentar el coste de operación de cada entorno.

---

## 2. Objetivos y criterios de aceptación

| # | Criterio | Cómo se verifica |
|---|----------|------------------|
| 1 | `terraform validate` pasa en los 3 entornos | Comando sin errores |
| 2 | `terraform fmt -check -recursive` no detecta cambios | Comando sin diff |
| 3 | `terraform plan` genera un plan coherente en `dev` | Revisión del plan |
| 4 | Los 3 entornos comparten módulos y solo difieren en `*.tfvars` | Revisión de código |
| 5 | Documentación de cada módulo generada con `terraform-docs` | Bloques presentes y al día |
| 6 | Documento de costes estimados por entorno | `docs/COSTS.md` |
| 7 | El pipeline de CI valida formato y sintaxis en cada cambio | GitHub Actions en verde |
| 8 | Un entorno se puede crear y destruir por completo sin recursos huérfanos | Ciclo `apply` → `destroy` en `dev` |

**Fuera de alcance de esta fase:**

- Despliegue de la aplicación (lo gestiona el equipo de producto).
- Gestión de DNS y dominios propios.
- Pipeline de entrega continua que aplique cambios automáticamente.
- Certificados TLS y terminación HTTPS (planificado para una fase posterior).

---

## 3. Stack y requisitos previos

- **Terraform** >= 1.7
- **Proveedor AWS** (`hashicorp/aws`) ~> 5.x
- **Cuenta AWS** con permisos para crear recursos de red, cómputo, RDS y S3
- **terraform-docs** para la documentación de módulos
- **tflint** y **trivy** (o **checkov**) para linting y análisis de seguridad
- **GitHub Actions** para integración continua
- **AWS CLI** configurado en local

---

## 4. Arquitectura objetivo

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
2. El ALB reparte la carga entre las instancias **EC2** del **Auto Scaling Group**
   ubicadas en las subredes privadas.
3. Las instancias acceden a **RDS** en las subredes de base de datos, que están aisladas
   y sin salida a internet.
4. Las instancias obtienen salida a internet (actualizaciones de sistema, etc.) a través
   del **NAT Gateway**.
5. **S3** proporciona almacenamiento de objetos para activos estáticos y logs.

**Decisiones de diseño:**

- Tres niveles de subredes (pública / privada / base de datos) para aislar la capa de
  datos del tráfico entrante directo.
- En `dev` y `staging`: un único NAT Gateway para reducir coste. En `prod`: un NAT
  Gateway por AZ para evitar un punto único de fallo.
- En `dev` y `staging`: RDS en single-AZ con instancias pequeñas. En `prod`: RDS
  Multi-AZ para alta disponibilidad.

---

## 5. Estructura del repositorio

```
terraform-aws-web-infra/
├── README.md
├── .gitignore
├── .terraform-docs.yml
├── .tflint.hcl
├── .github/
│   └── workflows/
│       └── ci.yml
├── docs/
│   ├── ARCHITECTURE.md
│   └── COSTS.md
├── scripts/
│   ├── bootstrap-backend.sh      # crea el bucket S3 + tabla DynamoDB del estado
│   └── gen-docs.sh               # ejecuta terraform-docs en todos los módulos
├── modules/
│   ├── networking/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   ├── versions.tf
│   │   └── README.md             # generado por terraform-docs
│   ├── security/
│   │   └── (misma estructura)
│   ├── compute/
│   │   └── (misma estructura)
│   ├── database/
│   │   └── (misma estructura)
│   └── storage/
│       └── (misma estructura)
└── environments/
    ├── dev/
    │   ├── main.tf               # invoca los módulos
    │   ├── variables.tf
    │   ├── outputs.tf
    │   ├── providers.tf
    │   ├── backend.tf
    │   └── terraform.tfvars
    ├── staging/
    │   └── (misma estructura que dev)
    └── prod/
        └── (misma estructura que dev)
```

**Regla de diseño:** las carpetas de `environments/` **no contienen recursos**, solo
invocan módulos y pasan variables. Toda la lógica de infraestructura vive en `modules/`.

---

## 6. Convenciones de código

- **Nomenclatura de recursos:** `${var.project_name}-${var.environment}-<recurso>`,
  p. ej. `webinfra-dev-vpc`.
- **Etiquetado obligatorio** (vía `default_tags` en el provider): `Project`,
  `Environment`, `ManagedBy = "terraform"`, `Owner`.
- **Variables:** todas con `description` y `type`, y con bloques `validation` donde
  aplique (CIDRs, valores de entorno permitidos, etc.).
- **Outputs:** cada módulo expone los identificadores y ARNs que otros módulos o los
  operadores necesiten.
- **Formato:** ejecutar `terraform fmt` antes de cada commit.
- **Gestión de secretos:** la contraseña de la base de datos no tiene valor por defecto,
  se marca `sensitive = true`, se genera con `random_password` y se almacena en AWS
  Secrets Manager. Nunca se versiona en un `.tfvars`.
- **`versions.tf`** en cada módulo fija `required_version` y `required_providers`.

---

## 7. Especificación de los módulos

### 7.1 `modules/networking`

**Crea:** VPC, Internet Gateway, subredes públicas/privadas/de base de datos (una por
AZ), NAT Gateway(s), Elastic IPs, tablas de rutas y sus asociaciones, y
`aws_db_subnet_group`.

**Inputs principales:**

| Variable | Tipo | Notas |
|----------|------|-------|
| `project_name` | string | prefijo de nombres |
| `environment` | string | dev/staging/prod |
| `vpc_cidr` | string | con `validation` de CIDR |
| `availability_zones` | list(string) | normalmente 2 |
| `public_subnet_cidrs` | list(string) | una por AZ |
| `private_subnet_cidrs` | list(string) | una por AZ |
| `database_subnet_cidrs` | list(string) | una por AZ |
| `enable_nat_gateway` | bool | default `true` |
| `single_nat_gateway` | bool | `true` en dev/staging, `false` en prod |
| `tags` | map(string) | etiquetas adicionales |

**Outputs:** `vpc_id`, `vpc_cidr`, `public_subnet_ids`, `private_subnet_ids`,
`database_subnet_ids`, `db_subnet_group_name`, `nat_gateway_ids`.

**Detalle:** las subredes de base de datos no tienen ruta a internet ni al NAT. Las
privadas salen por el NAT; las públicas por el Internet Gateway.

### 7.2 `modules/security`

**Crea:** los Security Groups y sus reglas.

- `alb_sg`: entrada en 80/443 desde `0.0.0.0/0`, salida libre.
- `app_sg`: entrada únicamente desde `alb_sg` al puerto de la aplicación; salida libre.
- `db_sg`: entrada únicamente desde `app_sg` al puerto de la base de datos
  (5432 PostgreSQL / 3306 MySQL); sin salida a internet.

**Inputs:** `project_name`, `environment`, `vpc_id`, `app_port`, `db_port`, `tags`.
**Outputs:** `alb_sg_id`, `app_sg_id`, `db_sg_id`.

**Detalle:** los Security Groups se referencian entre sí por ID, no por CIDR, para que
el aislamiento entre capas sea efectivo.

### 7.3 `modules/compute`

**Crea:** Launch Template, Auto Scaling Group, Application Load Balancer, Target Group,
Listener, rol IAM e Instance Profile para las instancias, y una política de escalado.

**Inputs principales:** `project_name`, `environment`, `vpc_id`, `public_subnet_ids`
(para el ALB), `private_subnet_ids` (para el ASG), `app_sg_id`, `alb_sg_id`,
`instance_type`, `min_size`, `max_size`, `desired_capacity`, `app_port`, `ami_id`
(o un `data` que busque la última Amazon Linux), `user_data` (script de arranque),
`tags`.

**Outputs:** `alb_dns_name`, `alb_arn`, `asg_name`, `target_group_arn`.

**Detalle:**

- La AMI se resuelve vía `data "aws_ami"` filtrando la última Amazon Linux 2023.
- El `user_data` instala y arranca un servidor web simple (p. ej. nginx con una página
  que muestre el hostname) para validar el balanceo de carga de extremo a extremo.
- El health check del Target Group apunta a `/`.
- Política de escalado por CPU mediante target tracking (objetivo en torno al 60 %).

### 7.4 `modules/database`

**Crea:** instancia RDS (PostgreSQL o MySQL), usando el `db_subnet_group` y el `db_sg`.

**Inputs principales:** `project_name`, `environment`, `db_subnet_group_name`,
`db_sg_id`, `engine`, `engine_version`, `instance_class`, `allocated_storage`,
`multi_az` (`false` en dev/staging, `true` en prod), `db_name`, `db_username`,
`db_password` (sensible, sin default), `backup_retention_period`,
`deletion_protection`, `skip_final_snapshot`, `tags`.

**Outputs:** `db_endpoint`, `db_port`, `db_identifier` (no se expone la contraseña).

**Detalle:**

- `storage_encrypted = true`.
- En `dev`/`staging`: `skip_final_snapshot = true` y `deletion_protection = false`
  para permitir destruir el entorno limpiamente.
- En `prod`: lo contrario, y `backup_retention_period` >= 7 días.
- La contraseña se genera con `random_password` y se almacena en Secrets Manager; se
  expone el ARN del secreto como output, no el valor.

### 7.5 `modules/storage`

**Crea:** bucket S3 con configuración endurecida.

- Versionado activado.
- Cifrado en reposo (SSE-S3 o SSE-KMS).
- `aws_s3_bucket_public_access_block` con las cuatro opciones en `true`.
- Política de ciclo de vida (p. ej. transición a Infrequent Access a los 30 días,
  expiración de versiones antiguas a los 90 días).
- Nombre globalmente único mediante sufijo aleatorio o `account_id`.

**Inputs:** `project_name`, `environment`, `force_destroy` (`true` solo en dev), `tags`.
**Outputs:** `bucket_id`, `bucket_arn`, `bucket_domain_name`.

---

## 8. Entornos

Cada carpeta de `environments/` tiene la misma estructura. Solo cambian los valores de
`terraform.tfvars`.

**`providers.tf`** — provider AWS con `default_tags`.

**`backend.tf`** — estado remoto en S3 con bloqueo en DynamoDB. Cada entorno usa una
`key` distinta dentro del mismo bucket de estado:

```hcl
terraform {
  backend "s3" {
    bucket         = "<bucket-de-estado>"
    key            = "env/dev/terraform.tfstate"   # staging y prod cambian esta key
    region         = "eu-west-1"
    dynamodb_table = "<tabla-de-locks>"
    encrypt        = true
  }
}
```

**`main.tf`** — invoca los módulos en orden de dependencia: networking → security →
storage → database → compute, encadenando los outputs (p. ej. `module.networking.vpc_id`).

### Tabla comparativa de entornos

| Parámetro | dev | staging | prod |
|-----------|-----|---------|------|
| `vpc_cidr` | `10.0.0.0/16` | `10.1.0.0/16` | `10.2.0.0/16` |
| AZs | 2 | 2 | 2-3 |
| `single_nat_gateway` | `true` | `true` | `false` |
| `instance_type` (EC2) | `t3.micro` | `t3.micro` | `t3.small` |
| ASG min/desired/max | 1 / 1 / 2 | 1 / 2 / 3 | 2 / 2 / 6 |
| RDS `instance_class` | `db.t3.micro` | `db.t3.micro` | `db.t3.small` |
| RDS `multi_az` | `false` | `false` | `true` |
| `deletion_protection` | `false` | `false` | `true` |
| `skip_final_snapshot` | `true` | `true` | `false` |
| `force_destroy` (S3) | `true` | `false` | `false` |

---

## 9. Plan de implementación por fases

La implementación se aborda **una fase cada vez**. Tras cada fase se ejecuta
`terraform fmt -recursive` y `terraform validate` en `environments/dev`, y se hace un
commit independiente.

1. **Fase 0 — Andamiaje.** Estructura de carpetas, `.gitignore` (ignorar `.terraform/`,
   `*.tfstate*` y `*.tfvars` con secretos; el `.terraform.lock.hcl` sí se versiona),
   `README.md` inicial y `versions.tf` de cada módulo.
2. **Fase 1 — Backend remoto.** Script `bootstrap-backend.sh` que crea el bucket S3 y la
   tabla DynamoDB para el estado. Se ejecuta una sola vez, antes del primer `init`.
3. **Fase 2 — Módulo networking.** Implementación y validación aislada.
4. **Fase 3 — Módulo security.** Security Groups.
5. **Fase 4 — Módulo storage.** Bucket S3.
6. **Fase 5 — Módulo database.** RDS + Secrets Manager.
7. **Fase 6 — Módulo compute.** ALB + ASG + Launch Template + IAM.
8. **Fase 7 — Entorno dev.** Cableado de todos los módulos en `environments/dev`,
   `terraform plan` y revisión.
9. **Fase 8 — staging y prod.** Réplica de la estructura y ajuste de `terraform.tfvars`.
10. **Fase 9 — terraform-docs.** `.terraform-docs.yml`, inyección de los bloques en cada
    `modules/*/README.md` y script `gen-docs.sh`.
11. **Fase 10 — Documentación de costes.** `docs/COSTS.md` (ver sección 10).
12. **Fase 11 — CI.** GitHub Actions: `fmt -check`, `init -backend=false`, `validate`,
    `tflint` y análisis de seguridad.
13. **Fase 12 — README final.** Diagrama, guía de despliegue, sección de destrucción y
    decisiones de diseño.

---

## 10. Documentación de costes (`docs/COSTS.md`)

Cada entorno debe llevar asociada una estimación de coste de operación, para que el
equipo pueda tomar decisiones informadas sobre cuándo mantener entornos activos.

El documento debe incluir:

- **Tabla de coste mensual estimado por recurso y por entorno.**
- Aviso explícito de que **NAT Gateway y ALB no entran en la capa gratuita** y son el
  mayor componente de coste (en torno a 16-35 USD/mes cada uno por horas más tráfico).
- Recomendación operativa: destruir `dev` y `staging` cuando no estén en uso, y mantener
  `single_nat_gateway` fuera de producción.
- Enlace a la AWS Pricing Calculator y aclaración de que los precios varían por región.
- Nota de que las cifras son estimaciones, no una factura garantizada.

Estructura sugerida del fichero:

```markdown
# Estimación de costes

> Cifras orientativas para la región eu-west-1, mayo 2026. Verificar siempre con
> la AWS Pricing Calculator. Los precios pueden variar.

## Resumen por entorno (USD/mes, aprox.)

| Entorno | Encendido de forma continua | Destruido tras su uso |
|---------|-----------------------------|------------------------|
| dev     | ~XX                         | ~0                     |
| staging | ~XX                         | ~0                     |
| prod    | ~XXX                        | n/a                    |

## Desglose (entorno dev)

| Recurso          | Cantidad | Capa gratuita | Coste fuera de capa gratuita |
|------------------|----------|---------------|------------------------------|
| EC2 t3.micro     | 1        | 750 h/mes     | ...                          |
| ALB              | 1        | No            | ~16 USD/mes + LCU            |
| NAT Gateway      | 1        | No            | ~32 USD/mes + datos          |
| RDS db.t3.micro  | 1        | 750 h/mes     | ...                          |
| S3               | 1        | 5 GB          | despreciable                 |

## Recomendaciones para controlar el gasto
- Ejecutar `terraform destroy` en entornos no productivos cuando no se usen.
- Usar `single_nat_gateway = true` fuera de producción.
```

---

## 11. Documentación de módulos con terraform-docs

`.terraform-docs.yml` en la raíz del repositorio:

```yaml
formatter: markdown table
sections:
  show:
    - inputs
    - outputs
    - providers
    - resources
output:
  file: README.md
  mode: inject
  template: |-
    <!-- BEGIN_TF_DOCS -->
    {{ .Content }}
    <!-- END_TF_DOCS -->
sort:
  enabled: true
  by: name
```

Cada `modules/*/README.md` comienza con una descripción del módulo escrita a mano,
seguida de los marcadores `<!-- BEGIN_TF_DOCS -->` / `<!-- END_TF_DOCS -->`. El script
`scripts/gen-docs.sh` recorre `modules/*` y ejecuta `terraform-docs` en cada uno. La
documentación generada debe regenerarse en cada cambio de variables u outputs.

---

## 12. Integración continua (`.github/workflows/ci.yml`)

Pipeline que se dispara en `push` y `pull_request`. Pasos:

1. `actions/checkout`.
2. `hashicorp/setup-terraform`.
3. `terraform fmt -check -recursive`.
4. Para cada módulo y entorno: `terraform init -backend=false` + `terraform validate`.
5. `tflint` sobre todos los módulos.
6. Análisis de seguridad con `trivy config .` o `checkov`.
7. `terraform-docs` en modo verificación, para asegurar que la documentación está al día.

El pipeline **no ejecuta `apply`**; su función es validar formato, sintaxis y seguridad.
La aplicación de cambios es un paso manual y deliberado.

---

## 13. Contenido del README del repositorio

1. Título y descripción del proyecto.
2. Diagrama de arquitectura.
3. Stack y requisitos previos.
4. Estructura del repositorio.
5. Guía de despliegue paso a paso:
   - Configuración de credenciales AWS.
   - Ejecución de `bootstrap-backend.sh`.
   - `cd environments/dev && terraform init && terraform plan && terraform apply`.
   - Verificación: el DNS del ALB aparece en los outputs.
6. Procedimiento de destrucción (`terraform destroy`), con aviso sobre coste.
7. Enlaces a `docs/COSTS.md` y `docs/ARCHITECTURE.md`.
8. Decisiones de diseño y trade-offs.
9. Alcance, fuera de alcance y mejoras planificadas.
10. Licencia.

---

## 14. Mejoras planificadas (fases posteriores)

- Terminación HTTPS en el ALB con certificado de ACM y dominio en Route 53.
- Pipeline de entrega: `terraform plan` automático en cada PR y `apply` con aprobación
  manual tras la revisión.
- Evaluar la migración de EC2 + ASG a contenedores (ECS Fargate o EKS).
- Autenticación con OIDC en lugar de claves de acceso estáticas para el CI.
- Módulo de observabilidad: dashboards y alarmas en CloudWatch.
- Pruebas automatizadas de infraestructura con Terratest.

---

## 15. Checklist de cierre

- [ ] `terraform fmt -check -recursive` sin cambios.
- [ ] `terraform validate` correcto en los 3 entornos.
- [ ] Ningún secreto ni fichero `*.tfstate` versionado.
- [ ] `README.md` de cada módulo con documentación generada por terraform-docs.
- [ ] `docs/COSTS.md` completo y con cifras.
- [ ] Pipeline de CI en verde.
- [ ] README del repositorio con diagrama y guía de despliegue.
- [ ] Historial de commits limpio, una entrega por fase.
- [ ] Ciclo completo `apply` → verificación → `destroy` probado en `dev`.
