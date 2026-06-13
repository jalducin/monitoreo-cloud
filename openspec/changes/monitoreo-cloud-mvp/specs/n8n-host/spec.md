## ADDED Requirements

### Requirement: n8n self-hosted con Docker Compose y backend PostgreSQL

El sistema SHALL ejecutar n8n en la EC2 mediante Docker Compose, usando una imagen con versión fijada
(no `latest`) y configurado con `DB_TYPE=postgresdb` apuntando a la instancia de **AWS RDS PostgreSQL**
del proyecto, de modo que workflows y credenciales persistan en la base de datos gestionada y
sobrevivan a la recreación o reemplazo del contenedor y de la EC2.

#### Scenario: Arranque del stack

- **WHEN** el operador ejecuta `docker compose up -d` en la EC2 con las variables de conexión a RDS definidas
- **THEN** el contenedor de n8n queda en estado `running`, conecta a la BD PostgreSQL de RDS y la UI responde en el puerto 5678

#### Scenario: Persistencia tras recreación del contenedor o la EC2

- **WHEN** el contenedor de n8n (o la propia EC2) se recrea y se vuelve a apuntar al mismo RDS
- **THEN** los workflows y credenciales previamente guardados siguen presentes porque viven en RDS PostgreSQL

#### Scenario: Versión de imagen fijada

- **WHEN** se revisa `docker-compose.yml`
- **THEN** la imagen de n8n referencia una etiqueta de versión concreta y no `latest`

#### Scenario: Credenciales de la BD fuera del repo

- **WHEN** se inspecciona el repositorio y la configuración de n8n
- **THEN** las credenciales de conexión a RDS provienen del `.env` del host (no versionado) o de un secreto, nunca de valores embebidos en el compose versionado

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
