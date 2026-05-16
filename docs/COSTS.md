# Estimación de costes

> Cifras orientativas para la región **eu-west-1 (Irlanda)**, mayo 2026.
> Verificar siempre con la [AWS Pricing Calculator](https://calculator.aws/#/).
> Los precios pueden variar.

## Resumen por entorno (USD/mes, aprox.)

| Entorno | Encendido de forma continua | Destruido tras su uso |
|---------|-----------------------------|------------------------|
| dev     | ~60-80                      | ~0                     |
| staging | ~60-80                      | ~0                     |
| prod    | ~150-200                    | n/a                    |

> **Nota:** Los rangos reflejan la variación en tráfico (LCU del ALB) y uso de datos del NAT Gateway.

## Desglose detallado (entorno dev)

| Recurso | Cantidad | Capa gratuita | Coste fuera de capa gratuita |
|---------|----------|---------------|------------------------------|
| EC2 t3.micro | 1 | 750 h/mes (t2/t3.micro, 12 meses primeros) | ~0 USD/mes (dentro de capa gratuita si aplica) |
| ALB | 1 | **No** | ~16 USD/mes (horas) + LCU variable (~0-10 USD) |
| NAT Gateway | 1 | **No** | ~32 USD/mes (horas) + datos procesados (~0-5 USD) |
| RDS db.t3.micro | 1 | 750 h/mes (primeros 12 meses) | ~0 USD/mes (dentro de capa gratuita si aplica) |
| EBS gp3 (20 GB) | 1 | — | ~1.60 USD/mes |
| S3 Standard | 1 | 5 GB | despreciable (< 0.03 USD/mes) |
| DynamoDB (lock table) | 1 | 25 WCU + 25 RCU | ~0 USD/mes (dentro de capa gratuita) |
| Elastic IP | 1 | 1 asociada | ~0 USD/mes |
| Secrets Manager | 1 | — | ~0.40 USD/mes |
| **Total estimado** | | | **~50-65 USD/mes** |

### Aviso importante: NAT Gateway y ALB

**NAT Gateway** y **Application Load Balancer** **NO entran en la capa gratuita** de AWS.
Son el mayor componente de coste de esta infraestructura:

- **NAT Gateway**: ~0.045 USD/hora × 730 h ≈ **32.85 USD/mes** + coste por datos procesados.
- **ALB**: ~0.0225 USD/hora × 730 h ≈ **16.43 USD/mes** + coste por LCU (Load Balancer Capacity Units).

Estos recursos se facturan por hora, independientemente de si hay tráfico o no.

## Entorno staging

Similar a dev pero con ASG de 2-3 instancias (en lugar de 1-2):

| Recurso | Diferencia vs dev | Coste adicional |
|---------|-------------------|-----------------|
| EC2 t3.micro | +1 instancia adicional | ~0 USD (capa gratuita) |
| EBS gp3 | +20 GB | ~1.60 USD/mes |
| ALB + NAT | Igual | Igual |
| **Total estimado** | | **~52-67 USD/mes** |

## Entorno prod

Configuración de producción con alta disponibilidad:

| Recurso | Cantidad | Coste estimado |
|---------|----------|----------------|
| EC2 t3.small | 2-6 | ~15-45 USD/mes (fuera de capa gratuita) |
| ALB | 1 | ~16 USD/mes + LCU |
| NAT Gateway × 2 | 2 | ~65 USD/mes + datos |
| RDS db.t3.small (Multi-AZ) | 1 | ~35 USD/mes |
| EBS gp3 (20 GB × 2) | 2 | ~3.20 USD/mes |
| S3 Standard | 1 | despreciable |
| Secrets Manager | 1 | ~0.40 USD/mes |
| **Total estimado** | | **~135-195 USD/mes** |

## Recomendaciones para controlar el gasto

1. **Destruir entornos no productivos cuando no se usen.** Ejecutar `terraform destroy` en `dev` y `staging` al final de cada jornada de desarrollo elimina el coste por completo.
2. **Usar `single_nat_gateway = true` fuera de producción.** Un único NAT Gateway es suficiente para dev/staging y reduce el coste a la mitad.
3. **Programar destrucción automática.** Considerar un script o pipeline que destruya entornos de desarrollo tras N horas de inactividad.
4. **Monitorizar con AWS Cost Explorer.** Configurar alertas de presupuesto para detectar desviaciones tempranas.

## Enlaces útiles

- [AWS Pricing Calculator](https://calculator.aws/#/)
- [AWS Free Tier](https://aws.amazon.com/free/)
- [AWS Cost Explorer](https://aws.amazon.com/aws-cost-management/aws-cost-explorer/)

## Disclaimer

Las cifras de este documento son **estimaciones orientativas** basadas en precios públicos de AWS para la región eu-west-1 a mayo 2026. Los precios reales pueden variar según:

- Tráfico real (LCU del ALB, datos del NAT Gateway)
- Cambios de precios por parte de AWS
- Impuestos y descuentos por volumen (Enterprise Discount Program, Reserved Instances, etc.)

**Verificar siempre los costes actualizados antes de tomar decisiones de infraestructura.**
