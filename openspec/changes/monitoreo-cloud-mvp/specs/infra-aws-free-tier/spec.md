## ADDED Requirements

### Requirement: Provisión idempotente de la EC2 base

El sistema SHALL provisionar, mediante scripts de AWS CLI, una instancia EC2 de un tipo
**free-tier-eligible** en la región (por defecto `t3.micro`, x86_64) con Amazon Linux 2023 en
`us-east-2`, de forma idempotente: si ya existe una instancia con el tag `Project=monitoreo-cloud`
en estado `running`/`pending`, el script NO MUST crear otra. El tipo elegible se valida contra la
API de AWS (varía por región/cuenta), no se asume fijo.

#### Scenario: Primera provisión

- **WHEN** el operador ejecuta el script de provisión y no existe ninguna instancia con el tag del proyecto
- **THEN** se crea exactamente una EC2 `t3.micro` Amazon Linux 2023 con los tags `Project=monitoreo-cloud`, `Env=free-tier`, `ManagedBy=cli` y el script imprime su `InstanceId` e IP pública

#### Scenario: Re-ejecución idempotente

- **WHEN** el operador ejecuta el script de provisión y ya existe una instancia del proyecto en `running` o `pending`
- **THEN** el script no crea una nueva instancia, reporta la existente y termina con código de éxito

#### Scenario: Tipo de instancia fuera de Free Tier

- **WHEN** se intenta provisionar con un tipo de instancia que no es free-tier-eligible en la región
- **THEN** el script aborta con error listando los tipos elegibles disponibles, salvo override explícito (`ALLOW_NON_FREE_TIER=1`)

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

### Requirement: Provisión idempotente de RDS PostgreSQL (Free Tier)

El sistema SHALL provisionar, mediante AWS CLI, una instancia de **RDS PostgreSQL** `db.t3.micro`,
Single-AZ, 20 GB gp2, sin acceso público, en `us-east-2`, de forma idempotente. El tipo de instancia
NO MUST salir de los tipos elegibles de Free Tier (`db.t3.micro`/`db.t4g.micro`) salvo override explícito.
La base de datos SHALL ser accesible **solo** desde el security group de la EC2 (puerto 5432).

#### Scenario: Primera provisión de la BD

- **WHEN** el operador ejecuta el script de provisión y no existe una instancia RDS con el identificador del proyecto
- **THEN** se crea una RDS PostgreSQL `db.t3.micro` Single-AZ, sin acceso público, etiquetada con `Project=monitoreo-cloud`, y el script reporta su endpoint

#### Scenario: Re-ejecución idempotente

- **WHEN** ya existe la instancia RDS del proyecto
- **THEN** el script no crea otra y reporta el endpoint existente

#### Scenario: Acceso de red restringido

- **WHEN** se revisan las reglas del security group de la BD
- **THEN** el puerto 5432 solo admite tráfico desde el security group de la EC2 del proyecto, no desde `0.0.0.0/0`

#### Scenario: Tipo fuera de Free Tier

- **WHEN** se intenta provisionar con una clase de instancia distinta de `db.t3.micro`/`db.t4g.micro`
- **THEN** el script aborta explicando el límite de Free Tier, salvo override explícito

#### Scenario: Credenciales de la BD seguras

- **WHEN** se crea la instancia RDS
- **THEN** la contraseña maestra se toma de una variable de entorno/secreto y nunca se imprime ni se versiona

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

El sistema SHALL proveer un script de teardown que elimina todos los recursos creados (instancia EC2,
**instancia RDS**, security groups, key pair, rol IAM y, opcionalmente, el budget), filtrando por los
tags/identificadores del proyecto, y MUST pedir confirmación explícita o el flag `--yes` antes de destruir.

#### Scenario: Teardown con confirmación

- **WHEN** el operador ejecuta el teardown con `--yes`
- **THEN** se terminan/eliminan los recursos con el tag `Project=monitoreo-cloud` (incluida la RDS, omitiendo snapshot final) y el script verifica con `describe-*` que ya no existen

#### Scenario: Teardown sin recursos

- **WHEN** se ejecuta el teardown y no hay recursos del proyecto
- **THEN** el script no falla y reporta que no había nada que eliminar
