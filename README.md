# Plantilla SDD — Spec-Driven Development (OpenSpec)

Plantilla **reutilizable y agnóstica de tecnología** para arrancar proyectos con un flujo de
**desarrollo guiado por especificaciones (SDD)** sobre [OpenSpec](https://github.com/Fission-AI/OpenSpec).
Sirve para Python, PHP, React, n8n, SQL, CLIs, etc. Viene preparada para trabajar con **Claude Code** y
**Gemini CLI**.

La documentación, los comentarios y los artefactos se redactan en **español**.

## 🧭 ¿Qué es SDD / OpenSpec?

La especificación es la fuente de verdad. Cada cambio recorre artefactos antes de codificar:

```
proposal  →  specs  →  design  →  tasks  →  (apply / implementación)  →  archive
   ¿por qué?   ¿qué?     ¿cómo?    ¿pasos?       código + verificación      cierre
```

## 📁 Estructura

```
.
├── README.md                      # este archivo
├── AGENTS.md / CLAUDE.md / GEMINI.md  # contexto por asistente; importan docs/base-standards.md
├── openspec/
│   ├── config.yaml                # contexto + reglas del proyecto (RELLENAR placeholders)
│   ├── project.md                 # contexto del proyecto (RELLENAR)
│   ├── schemas/spec-driven/       # schema + plantillas de artefactos (proposal/spec/design/tasks)
│   ├── specs/                     # capabilities vigentes (vacío al inicio)
│   └── changes/archive/           # cambios archivados (vacío al inicio)
├── docs/
│   ├── base-standards.md          # principios base, idioma, skills, planificación, reglas OpenSpec
│   └── documentation-standards.md # estándares de documentación
├── ai-specs/                      # FUENTE CANÓNICA reutilizable
│   ├── agents/                    # agentes (backend/frontend genéricos, product-strategy)
│   ├── skills/                    # skills (genéricas)
│   └── scripts/
├── .claude/                       # Claude Code: commands (/opsx:*), skills, agents, rules, scripts
└── .gemini/                       # Gemini CLI: commands (opsx/*.toml), skills, agents, rules
```

## 🚀 Cómo usarla en un proyecto nuevo

1. **Copia** el contenido de esta carpeta en la raíz del proyecto nuevo.
2. **Rellena** los placeholders `<...>` en:
   - `openspec/config.yaml` → stack, arquitectura, dominio.
   - `openspec/project.md` → descripción, comandos, convenciones.
3. **Agrega** los `docs/<area>-standards.md` que apliquen (p. ej. `backend-standards.md`,
   `frontend-standards.md`, `sql-standards.md`, `n8n-standards.md`) y enlázalos desde `config.yaml`.
4. **Instala** la CLI de OpenSpec (requerida por los comandos): ver su documentación oficial.
5. **Inicializa git** si el proyecto lo usará (esta plantilla no incluye repositorio).
6. **Escribe el README del proyecto** siguiendo la estructura de alta calidad de abajo.

## 📝 README de tu proyecto (estructura de alta calidad)

El README del proyecto es la **puerta de entrada**: que un nuevo integrante entienda y arranque sin contexto extra. Estructura recomendada (headers con emoji para escaneabilidad):

```markdown
# <Proyecto> — <una línea de qué es>
> Estado del proyecto + enlace al alcance funcional.

## 🎯 Qué resuelve        # problema + valor (bullets), o actores y capacidades
## 🏗️ Arquitectura        # diagrama ASCII de capas (ver ejemplo abajo) + enlace a ARCHITECTURE.md
## 🛠️ Tecnologías         # stack real
## 📦 Requisitos           # versiones (Node, Docker…), con .nvmrc
## 🚀 Configuración        # quickstart (clonar → instalar → levantar → correr)
## ⚙️ Scripts              # tabla de npm/make scripts
## 🧪 Pruebas y CI         # cómo verificar + qué corre la CI
## 📁 Estructura           # árbol de carpetas comentado
## 🔗 API                  # cómo se expone/genera la API (REST/OpenAPI/RPC…)
## 📚 Documentación        # índice de docs (apuntar a DOCS_INVENTORY como canónico)
## 🔄 Cómo contribuir (SDD)  # flujo en UNA sección: rama → spec (templates) → pruebas → verificación → PR a SDD → archive
## 📄 Licencia
```

**Ejemplo de diagrama de arquitectura (ASCII)** — *muestra de un proyecto BaaS/Supabase; **adáptalo a tu stack** (capas DDD, microservicios, etc.):*

```
┌──────────────────────────────────────────────────────────────────┐
│  CLIENTE — navegador / móvil                                       │
│  React · Vite · Tailwind · supabase-js                             │
└──────────────────────────────────────────────────────────────────┘
                    │  HTTPS  (REST · RPC · Auth · Realtime WS)
                    ▼
┌──────────────────────────────────────────────────────────────────┐
│  BACKEND (BaaS — Supabase)                                         │
│  ┌──────────┐ ┌─────────────┐ ┌──────────┐ ┌────────────────────┐ │
│  │  Auth    │ │  PostgREST  │ │ Realtime │ │  Edge Functions     │ │
│  │ (GoTrue) │ │  REST + RPC │ │  (WS)    │ │  (Deno)             │ │
│  └──────────┘ └─────────────┘ └──────────┘ └────────────────────┘ │
├──────────────────────────────────────────────────────────────────┤
│  PostgreSQL  ·  RLS multi-tenant  ·  RPC (SECURITY DEFINER)  ·     │
│  migraciones inmutables (fuente del esquema)                       │
└──────────────────────────────────────────────────────────────────┘
```

> Alternativa por capas (DDD / backend tradicional): Presentación → Aplicación → Dominio → Infraestructura.

> Reglas de oro: **una fuente canónica por dato** (los demás enlazan, no copian); **no hardcodear conteos** que se desfasan (test counts → la CI es la fuente de verdad); mantener un `docs/DOCS_INVENTORY.md` como índice maestro.

## ⚙️ Comandos del flujo

Mismos pasos en ambos agentes — en **Claude Code** como `/opsx:<x>`, en **Gemini CLI** como `opsx:<x>`:

| Comando      | Para qué |
|--------------|----------|
| `new`        | Iniciar un cambio nuevo (proposal → specs → design → tasks) |
| `ff`         | Fast-forward: generar todos los artefactos de un tirón |
| `continue`   | Continuar un cambio existente |
| `explore`    | Explorar/entender antes de proponer |
| `apply`      | Implementar las tareas del cambio |
| `verify`     | Verificar el cambio contra sus artefactos |
| `sync`       | Sincronizar specs |
| `archive`    | Archivar un cambio completado |
| `bulk-archive` | Archivar varios cambios |
| `onboard`    | Recorrido guiado por el flujo OpenSpec |

> Los comandos Gemini se generan desde los de Claude (`.gemini/commands/opsx/*.toml`). El argumento del
> usuario llega como `{{args}}`.

## 🤖 Agentes y skills

- **Fuente canónica**: `ai-specs/` (agentes y skills). `.claude/` y `.gemini/` la referencian.
- En Windows los symlinks suelen no sobrevivir a la copia; hay copias/punteros reales. Si necesitas
  materializar referencias, usa la skill `sync-agent-symlinks`.
- Agentes incluidos: `backend-developer` y `frontend-developer` (genéricos, ajústalos al stack) y
  `product-strategy-analyst`.

## ✅ Pasos obligatorios en cada cambio

Definidos en `.claude/rules/openspec-tasks-mandatory-steps.md` (agnósticos de tecnología):
crear feature branch → revisar/actualizar pruebas → ejecutar pruebas + reporte → **verificación manual
según el tipo de proyecto (el agente la ejecuta)** → actualizar documentación.

## 🎛️ Personalización

- **Idioma**: ajusta `docs/base-standards.md` §2 si tu proyecto requiere otro idioma.
- **Stack**: todo lo específico vive en `docs/*-standards.md` + `openspec/config.yaml`; el resto es genérico.
