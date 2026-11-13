# Informe FinOps de PreviewPanda

## Alcance

PreviewPanda crea una Lambda temporal por Pull Request y la elimina cuando el
PR se cierra o se mergea. El objetivo de FinOps es demostrar que los recursos
temporales tienen una vida limitada y que el equipo puede estimar, registrar y
controlar su costo.

## Supuestos de la estimación

| Concepto | Decisión del proyecto |
|---|---|
| Proveedor | AWS |
| Región | `us-east-1` |
| Cómputo | Lambda con imagen de contenedor, bajo demanda y escala a cero |
| Logs | CloudWatch Logs con retención de 7 días |
| Imágenes | Un repositorio ECR compartido y tags por PR/commit |
| State | Un objeto S3 por PR, con versionado y bloqueo |
| Presupuesto | USD 10 mensuales |
| Alertas de presupuesto | 50 %, 80 % y 100 % |
| Referencia inicial | USD 0–2 mensuales para el alcance de demostración |

La cifra de USD 0–2 es una referencia del plan del proyecto, no una factura
real. El costo final debe comprobarse en AWS Billing o Cost Explorer.

## Costo observado en la demo

En Cost Explorer se consultó el período **12/11/2026–13/11/2026**, usando un
filtro para los servicios relacionados con el proyecto: Lambda, S3 y ECR. El
total observado fue de **USD 0,00**. En el desglose visible apareció S3, pero no
se mostró un importe separado para ECR.

Este valor sirve como evidencia del costo observado durante esa ventana, pero
no debe presentarse como un costo exacto del PR #24: AWS puede redondear
importes muy pequeños, demorar la imputación y mezclar el consumo con otros
recursos de la cuenta. Por eso el CSV conserva `estimated_cost_usd` como una
estimación por tiempo de vida hasta contar con una imputación específica.

## Presupuesto de AWS

La cuenta tiene activo el presupuesto mensual `previewpanda-presupuesto` por
**USD 10,00**, iniciado el 01/11/2026. La captura disponible muestra un gasto
actual de **USD 0,00**, tres destinatarios con correo verificado y tres alertas
asociadas a cada destinatario. La pestaña **Alertas** confirma los umbrales:
50 % (USD 5,00), 80 % (USD 8,00) y 100 % (USD 10,00), todos sin superar.

## Recursos compartidos y temporales

### Compartidos

- Repositorio ECR.
- Bucket S3 del state.
- Proveedor OIDC y rol de CI.
- Presupuesto de AWS.
- Dashboard y alarma de CloudWatch.

### Por Pull Request

- Lambda `pp-pr-<n>`.
- Function URL.
- Rol de ejecución.
- Log group con retención de 7 días.
- Imagen `pr-<n>-<sha>` en ECR.
- Objeto de state `previews/pr-<n>/terraform.tfstate`.

Los recursos temporales son los que deben desaparecer al cerrar o mergear el
PR. Mantenerlos vivos es el principal riesgo de costo innecesario.

## Fórmula de registro por entorno

Para cada entorno se registran:

```text
lifetime_hours = (destroyed_at - created_at) en horas
estimated_cost_usd = costo estimado del entorno durante lifetime_hours
```

El CSV debe distinguir entre una estimación y un costo real. Mientras no exista
un dato de facturación asociado al PR, `estimated_cost_usd` debe documentarse
como estimación y no presentarse como una medición exacta.

## Medidas de ahorro

1. Lambda no mantiene servidores encendidos.
2. Los entornos se destruyen al cerrar o mergear el PR.
3. Un job nocturno elimina previews huérfanos de más de 3 días.
4. ECR conserva solamente las imágenes necesarias según su regla de ciclo de
   vida.
5. CloudWatch Logs conserva datos durante 7 días.
6. El proyecto utiliza una sola región.
7. El presupuesto de AWS avisa al 50 %, 80 % y 100 %.

## Evidencia que falta completar

- Una fila `created` y una fila `destroyed` en `docs/environments.csv`.
- Cálculo de `lifetime_hours` del PR de demostración.
- Confirmación de que no quedan Lambda, imágenes ni states después del destroy.

## Conclusión

El diseño mantiene bajo el costo porque Lambda escala a cero y los recursos
temporales tienen destrucción automática. La cifra inicial esperada es baja,
pero la entrega final debe separar claramente la proyección del proyecto de la
facturación observada en AWS.
