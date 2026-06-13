## ADDED Requirements

### Requirement: Provisión idempotente de la EC2 base

El sistema SHALL provisionar, mediante scripts de AWS CLI, una instancia EC2 `t2.micro` con Amazon
Linux 2023 en la región `us-east-2`, de forma idempotente: si ya existe una instancia con el tag
`Project=monitoreo-cloud` en estado `running`/`pending`, el script NO MUST crear otra.

#### Scenario: Primera provisión

- **WHEN** el operador ejecuta el script de provisión y no existe ninguna instancia con el tag del proyecto
- **THEN** se crea exactamente una EC2 `t2.micro` Amazon Linux 2023 con los tags `Project=monitoreo-cloud`, `Env=free-tier`, `ManagedBy=cli` y el script imprime su `InstanceId` e IP pública

#### Scenario: Re-ejecución idempotente

- **WHEN** el operador ejecuta el script de provisión y ya existe una instancia del proyecto en `running` o `pending`
- **THEN** el script no crea una nueva instancia, reporta la existente y termina con código de éxito

#### Scenario: Tipo de instancia fuera de Free Tier

- **WHEN** se intenta provisionar con un tipo de instancia distinto de `t2.micro`
- **THEN** el script aborta con error explicando que solo `t2.micro` está dentro del Free Tier, salvo override explícito

### Requirement: Key pair y security group mínimos

El sistema SHALL crear un key pair dedicado y un security group de mínimo privilegio: SSH (22) restringido
a la IP pública del operador y el puerto de n8n (5678) abierto solo a la IP del operador. El security group
NO MUST exponer SSH ni n8n a `0.0.0.0/0`.

#### Scenario: Creación del security group

- **WHEN** el script de provisión crea el security group
- **THEN** las reglas de entrada permiten 22 y 5678 únicamente desde la IP `/32` detectada del operador

#### Scenario: Llave privada protegida

- **WHEN** se genera el key pair
- **THEN** el archivo `.pem` se guarda con permisos restringidos fuera del árbol versionado y queda listado en `.gitignore`

### Requirement: Guardarraíles de costo (budget y alerta de billing)

El sistema SHALL crear un AWS Budget de **1 USD** mensual con alerta por correo al superar el umbral, y
SHALL documentar los comandos para revisar el gasto (`aws ce get-cost-and-usage`).

#### Scenario: Budget creado

- **WHEN** se ejecuta el script de guardarraíles de costo con un correo destino
- **THEN** existe un budget mensual de 1 USD con notificación configurada a ese correo

#### Scenario: Revisión de gasto documentada

- **WHEN** el operador consulta cómo verificar costos
- **THEN** la documentación provee el comando exacto de AWS CLI y la ruta al Billing Console

### Requirement: Teardown completo

El sistema SHALL proveer un script de teardown que elimina todos los recursos creados (instancia, security
group, key pair y, opcionalmente, el budget), filtrando por los tags del proyecto, y MUST pedir confirmación
explícita o el flag `--yes` antes de destruir.

#### Scenario: Teardown con confirmación

- **WHEN** el operador ejecuta el teardown con `--yes`
- **THEN** se terminan/eliminan los recursos con el tag `Project=monitoreo-cloud` y el script verifica con `describe-*` que ya no existen

#### Scenario: Teardown sin recursos

- **WHEN** se ejecuta el teardown y no hay recursos del proyecto
- **THEN** el script no falla y reporta que no había nada que eliminar
