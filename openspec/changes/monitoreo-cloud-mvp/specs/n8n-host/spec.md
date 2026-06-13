## ADDED Requirements

### Requirement: n8n self-hosted con Docker Compose

El sistema SHALL ejecutar n8n en la EC2 mediante Docker Compose, usando una imagen con versión fijada
(no `latest`), con un volumen persistente para los datos de n8n de modo que workflows y credenciales
sobrevivan a reinicios del contenedor.

#### Scenario: Arranque del stack

- **WHEN** el operador ejecuta `docker compose up -d` en la EC2
- **THEN** el contenedor de n8n queda en estado `running` y la UI responde en el puerto 5678

#### Scenario: Persistencia tras reinicio

- **WHEN** el contenedor de n8n se reinicia o recrea
- **THEN** los workflows y credenciales previamente guardados siguen presentes gracias al volumen persistente

#### Scenario: Versión de imagen fijada

- **WHEN** se revisa `docker-compose.yml`
- **THEN** la imagen de n8n referencia una etiqueta de versión concreta y no `latest`

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
