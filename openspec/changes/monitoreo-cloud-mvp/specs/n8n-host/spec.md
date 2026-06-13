## ADDED Requirements

### Requirement: n8n self-hosted con Docker Compose y backend PostgreSQL en contenedor

El sistema SHALL ejecutar n8n en la EC2 mediante Docker Compose, usando una imagen con versión fijada
(no `latest`) y configurado con `DB_TYPE=postgresdb` apuntando a un **contenedor de PostgreSQL** que
corre en el mismo `docker compose` (servicio `postgres`, imagen de versión fijada), con un volumen
persistente para los datos de la BD, de modo que workflows y credenciales sobrevivan a la recreación
del contenedor de n8n. La elección de contenedor (en vez de RDS) mantiene el costo en **$0 indefinido**.

#### Scenario: Arranque del stack

- **WHEN** el operador ejecuta `docker compose up -d` en la EC2
- **THEN** arranca primero el contenedor `postgres` (healthcheck OK) y luego n8n, que conecta a esa BD y expone la UI en el puerto 5678

#### Scenario: Persistencia tras recreación del contenedor de n8n

- **WHEN** el contenedor de n8n se recrea apuntando al mismo servicio/volumen de PostgreSQL
- **THEN** los workflows y credenciales previamente guardados siguen presentes porque viven en el volumen persistente de la BD

#### Scenario: Dependencia de arranque

- **WHEN** se levanta el stack
- **THEN** n8n no arranca hasta que el contenedor `postgres` reporta `healthy` (vía `depends_on` + healthcheck)

#### Scenario: Versión de imagen fijada

- **WHEN** se revisa `docker-compose.yml`
- **THEN** las imágenes de n8n y de postgres referencian etiquetas de versión concretas y no `latest`

#### Scenario: Credenciales de la BD fuera del repo

- **WHEN** se inspecciona el repositorio y la configuración de n8n
- **THEN** las credenciales de la BD provienen del `.env` del host (no versionado), nunca de valores embebidos en el compose versionado

### Requirement: Manejo seguro de secretos

El sistema SHALL gestionar los secretos (credenciales de n8n, tokens) vía variables de entorno o el
credential store de n8n. Ningún secreto NI archivo `.env` MUST quedar versionado en el repositorio.

#### Scenario: Secretos fuera del repo

- **WHEN** se inspecciona el repositorio
- **THEN** no existen archivos `.env`, `.pem` ni credenciales en el control de versiones y todos están en `.gitignore`

#### Scenario: Configuración por entorno

- **WHEN** n8n arranca en la EC2
- **THEN** toma sus variables sensibles del `.env` del host (no versionado) o del entorno, no de valores embebidos en el compose

### Requirement: Acceso controlado a la UI

El sistema SHALL proteger el acceso a la UI de n8n mediante autenticación básica habilitada y acceso de
red restringido por el security group; la UI NO MUST quedar accesible públicamente sin autenticación.

#### Scenario: Autenticación habilitada

- **WHEN** un usuario abre la URL de n8n
- **THEN** n8n solicita credenciales (basic auth) antes de permitir el acceso
