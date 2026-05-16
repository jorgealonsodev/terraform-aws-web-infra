# Arquitectura

## Descripción general

Este proyecto implementa una **arquitectura web de 3 niveles** sobre AWS usando Terraform.
El diseño separa las capas de presentación, aplicación y datos en subredes aisladas para
maximizar la seguridad y la disponibilidad.

## Diagrama de arquitectura

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

## Flujo de tráfico

1. El tráfico entrante llega al **Application Load Balancer (ALB)** en las subredes públicas.
2. El ALB reparte la carga entre las instancias **EC2** del **Auto Scaling Group** ubicadas en las subredes privadas.
3. Las instancias acceden a **RDS** en las subredes de base de datos, que están aisladas y sin salida directa a internet.
4. Las instancias obtienen salida a internet (actualizaciones de sistema, etc.) a través del **NAT Gateway**.
5. **S3** proporciona almacenamiento de objetos para activos estáticos y logs.

## Decisiones de diseño y trade-offs

### Subredes de 3 niveles

**Decisión:** Separar en subredes públicas, privadas y de base de datos.

**Por qué:** El aislamiento entre capas reduce la superficie de ataque. Un atacante que comprometa el ALB no tiene acceso directo a las instancias EC2 ni a la base de datos.

**Trade-off:** Mayor complejidad de red y más recursos (tablas de ruta, subredes) que una arquitectura plana.

### NAT Gateway: single vs multi-AZ

**Decisión:** Un único NAT Gateway en dev/staging, uno por AZ en prod.

**Por qué:** El NAT Gateway cuesta ~33 USD/mes. En entornos no productivos, el ahorro justifica el riesgo de un punto único de fallo. En producción, la disponibilidad es prioritaria.

**Trade-off:** Si el único NAT Gateway falla en dev/staging, las instancias privadas pierden acceso a internet hasta que se recupere.

### RDS: single-AZ vs Multi-AZ

**Decisión:** RDS single-AZ en dev/staging, Multi-AZ en prod.

**Por qué:** Multi-AZ duplica el coste de la instancia RDS. En producción, el failover automático justifica el coste adicional.

**Trade-off:** En dev/staging, una indisponibilidad de AZ implica que la base de datos no está disponible hasta que AWS la recupere.

### Security Groups por referencia (no por CIDR)

**Decisión:** Los security groups se referencian entre sí por ID, no por rango de IPs.

**Por qué:** Las IPs de las instancias EC2 pueden cambiar (auto-scaling). Referenciar por security group ID mantiene las reglas correctas independientemente de las IPs.

### Contraseñas gestionadas automáticamente

**Decisión:** La contraseña de RDS se genera con `random_password` y se almacena en AWS Secrets Manager.

**Por qué:** Evita versionar secretos en el repositorio y garantiza contraseñas fuertes y únicas por despliegue.

### Estado remoto con bloqueo

**Decisión:** Backend S3 + DynamoDB para el estado de Terraform.

**Por qué:** Permite trabajo en equipo sin conflictos de estado y protege contra escrituras concurrentes mediante el lock de DynamoDB.

## Descripción de los módulos

| Módulo | Descripción |
|--------|-------------|
| **networking** | VPC, subredes (pública/privada/BBDD), Internet Gateway, NAT Gateway(s), tablas de ruta, DB subnet group |
| **security** | Security Groups para ALB, App y DB con aislamiento entre capas |
| **storage** | Bucket S3 endurecido con versionado, cifrado, bloqueo público y reglas de ciclo de vida |
| **database** | Instancia RDS PostgreSQL con cifrado, contraseña autogenerada y almacenamiento en Secrets Manager |
| **compute** | ALB, Launch Template (Amazon Linux 2023), Auto Scaling Group, rol IAM, política de escalado por CPU |

## Entornos

| Parámetro | dev | staging | prod |
|-----------|-----|---------|------|
| VPC CIDR | `10.0.0.0/16` | `10.1.0.0/16` | `10.2.0.0/16` |
| NAT Gateway | Single | Single | Multi-AZ |
| EC2 Instance | t3.micro | t3.micro | t3.small |
| RDS Instance | db.t3.micro | db.t3.micro | db.t3.small |
| RDS Multi-AZ | No | No | Yes |

Cada entorno invoca los mismos módulos con diferentes valores de `terraform.tfvars`.
No hay lógica de infraestructura en los directorios de entorno — solo configuración.
