#!/usr/bin/env bash
# ==============================================================================
# Cronos AI — Bootstrap del repositorio
# Etapa 0 · Ejecutar UNA SOLA VEZ dentro del repositorio recién clonado.
#
#   git clone git@github.com:<usuario>/cronos-ai.git
#   cd cronos-ai
#   bash bootstrap_cronos.sh
#
# Idempotente: puede ejecutarse de nuevo sin destruir archivos existentes.
# ==============================================================================
set -euo pipefail

if [ -d .git ]; then
  echo "Repositorio git detectado. Continuando."
else
  echo "ADVERTENCIA: no se detecta un repositorio git en este directorio."
  read -r -p "¿Continuar de todos modos? [s/N] " r
  [ "$r" = "s" ] || exit 1
fi

# ------------------------------------------------------------------------------
# 1. Estructura de directorios
#    La separación refleja la restricción R1: el módulo 'decision' no debe
#    tener dependencias salientes hacia ejecucion, persistencia ni conectores.
# ------------------------------------------------------------------------------
DIRS=(
  "docs/maestro"
  "docs/derivados"
  "docs/diagramas"

  "infra/docker"
  "infra/wazuh/reglas"
  "infra/wazuh/agentes"
  "infra/tailscale"
  "infra/vm"

  "decision/prompts"
  "decision/esquemas"

  "validacion/catalogo"
  "validacion/exclusion"
  "validacion/limites"

  "ejecucion/playbooks/f1"
  "ejecucion/playbooks/f2"
  "ejecucion/playbooks/f3"
  "ejecucion/playbooks/f4"
  "ejecucion/playbooks/f5"
  "ejecucion/playbooks/f6"
  "ejecucion/plantilla"

  "orquestacion/n8n/workflows"
  "orquestacion/n8n/credenciales"

  "persistencia/sql"
  "persistencia/migraciones"

  "conectores/directorio"
  "conectores/gateway"
  "conectores/endpoint"
  "conectores/notificacion"

  "argos/squid"
  "argos/e2guardian"
  "argos/icap-bridge"
  "argos/ca"

  "temis"

  "pruebas/unitarias"
  "pruebas/regresion"
  "pruebas/conjuntos"
  "pruebas/adversariales"
  "pruebas/certificaciones"
  "pruebas/evidencia"
  "pruebas/consultas"

  "scripts"
)

for d in "${DIRS[@]}"; do
  mkdir -p "$d"
  [ -f "$d/.gitkeep" ] || touch "$d/.gitkeep"
done
echo "[1/5] Estructura de directorios creada."

# ------------------------------------------------------------------------------
# 2. .gitignore
# ------------------------------------------------------------------------------
if [ ! -f .gitignore ]; then
cat > .gitignore <<'EOF'
# --- Secretos ---------------------------------------------------------------
.env
*.env
!.env.example
secretos/
argos/ca/*.key
argos/ca/*.pem
argos/ca/*.crt
orquestacion/n8n/credenciales/*.json

# --- Python -----------------------------------------------------------------
__pycache__/
*.py[cod]
*.egg-info/
.venv/
venv/
.pytest_cache/
.coverage
htmlcov/

# --- Django / TEMIS ---------------------------------------------------------
db.sqlite3
/staticfiles/
/media/
temis/staticfiles/

# --- Datos y volúmenes ------------------------------------------------------
datos/
volumenes/
*.dump
*.sql.gz

# --- Virtualización ---------------------------------------------------------
*.vdi
*.vmdk
*.iso
*.ova

# --- Evidencia pesada -------------------------------------------------------
pruebas/evidencia/**/*.mp4
pruebas/evidencia/**/*.mkv

# --- Entornos de desarrollo -------------------------------------------------
.idea/
.vscode/
.DS_Store
*.swp
EOF
echo "[2/5] .gitignore creado."
else
echo "[2/5] .gitignore ya existe, se conserva."
fi

# ------------------------------------------------------------------------------
# 3. .env.example
#    NUNCA debe existir un .env real en el repositorio.
# ------------------------------------------------------------------------------
if [ ! -f .env.example ]; then
cat > .env.example <<'EOF'
# ==============================================================================
# Cronos AI — plantilla de variables de entorno
# Copiar a .env y completar. El archivo .env NO se versiona.
# ==============================================================================

# --- PostgreSQL -------------------------------------------------------------
POSTGRES_HOST=postgresql
POSTGRES_PORT=5432
POSTGRES_DB=cronos
POSTGRES_ADMIN_USER=cronos_admin
POSTGRES_ADMIN_PASSWORD=

# Rol del orquestador: INSERT en auditoria, nunca UPDATE ni DELETE
CRONOS_N8N_DB_USER=cronos_n8n
CRONOS_N8N_DB_PASSWORD=

# Rol del frontend: estrictamente de solo lectura sobre el esquema de n8n
CRONOS_FRONTEND_DB_USER=cronos_frontend
CRONOS_FRONTEND_DB_PASSWORD=

# --- n8n --------------------------------------------------------------------
N8N_HOST=n8n
N8N_PORT=5678
N8N_WEBHOOK_TOKEN=
N8N_ENCRYPTION_KEY=

# Secreto compartido entre TEMIS y n8n (aprobaciones y restablecimientos)
CRONOS_SECRETO_TEMIS_N8N=

# --- Ollama -----------------------------------------------------------------
OLLAMA_HOST=ollama
OLLAMA_PORT=11434
OLLAMA_MODELO=
OLLAMA_TIMEOUT_SEG=20
CRONOS_UMBRAL_CONFIANZA=0.70

# --- Wazuh ------------------------------------------------------------------
WAZUH_MANAGER_HOST=
WAZUH_API_USER=
WAZUH_API_PASSWORD=
WAZUH_INDEXER_HEAP=3g

# --- Samba AD DC (HERA) -----------------------------------------------------
AD_DOMINIO=cronos.local
AD_HOST=
AD_BIND_USER=
AD_BIND_PASSWORD=

# --- ARGOS ------------------------------------------------------------------
SQUID_PUERTO=3128
ICAP_PUERTO=1344
PRESIDIO_HOST=presidio
PRESIDIO_PORT=5001
ICAP_TIMEOUT_SEG=3
ICAP_TAMANO_MAX_MB=2

# --- Notificación -----------------------------------------------------------
SMTP_HOST=mailhog
SMTP_PORT=1025
BUZON_SOC=
BUZON_FUERA_DE_BANDA=

# --- TEMIS ------------------------------------------------------------------
DJANGO_SECRET_KEY=
DJANGO_DEBUG=False
DJANGO_ALLOWED_HOSTS=

# --- Límites de ejecución (§9.2 del maestro) --------------------------------
LT_01_NIVEL2_POR_HORA=5
LT_02_NIVEL2_POR_TITULAR_24H=2
LT_03_NIVEL1_POR_HORA=15
LT_04_TOTAL_POR_HORA=20
LT_05_POR_ACTIVO_15MIN=3
EOF
echo "[3/5] .env.example creado."
else
echo "[3/5] .env.example ya existe, se conserva."
fi

# ------------------------------------------------------------------------------
# 4. Convenciones de trabajo
# ------------------------------------------------------------------------------
if [ ! -f docs/convenciones.md ]; then
cat > docs/convenciones.md <<'EOF'
# Convenciones de trabajo — Cronos AI

## Ramas

| Rama | Propósito |
| :--- | :--- |
| `main` | Estable y probado. Solo recibe merge desde `develop` en hitos verificables. |
| `develop` | Integración continua. Origen de toda rama de característica. |
| `feature/*` | Un entregable funcional. Vida breve. |
| `fix/*` | Corrección de defecto detectado en integración. |
| `release/v1.0` | Versión congelada para la presentación final. |

Nunca se confirma directamente sobre `main` ni sobre `develop`.

## Mensajes de confirmación

```
tipo(ambito): descripción en imperativo, minúscula, sin punto final
```

Tipos: `feat`, `fix`, `docs`, `refactor`, `test`, `chore`.

Ámbitos: `decision`, `validacion`, `ejecucion`, `orquestacion`, `persistencia`,
`conectores`, `argos`, `temis`, `infra`, `pruebas`, `docs`.

Ejemplos:

```
feat(validacion): agrega verificacion de lista de exclusion
fix(persistencia): corrige calculo de hash_anterior en primer registro
test(regresion): agrega prueba REG-E5 de exclusion parcial de HERA
docs(maestro): incorpora DA-13 sobre tabla de temporizadores
```

Confirmar en unidades pequeñas y coherentes, no al final de la jornada.
El historial granular evidencia el aporte individual ante la evaluación.

## Solicitudes de incorporación

1. Toda rama se integra a `develop` mediante solicitud de incorporación.
2. Requiere revisión de **al menos un integrante distinto del autor**.
3. Las pruebas de regresión deben pasar antes de integrar.
4. El autor no integra su propia solicitud.

## Etiquetas de versión

Una etiqueta por etapa completada, conforme al plan de trabajo:

| Etiqueta | Etapa |
| :--- | :--- |
| `v0.1.0` | Repositorio y estructura |
| `v0.2.0` | ZEUS base: sistema operativo, Docker, VirtualBox, Tailscale |
| `v0.3.0` | Persistencia, n8n y notificación |
| `v0.4.0` | Wazuh, agentes y máquinas virtuales |
| `v0.5.0` | Ollama y prompts de clasificación |
| `v0.6.0` | Validador, exclusión y límites |
| `v0.7.0` | ARGOS y control DLP |
| `v0.8.0` | Los 25 playbooks |
| `v0.9.0` | TEMIS |
| `v1.0.0` | Validación completa |

## Regla de dependencias (restricción R1)

El módulo `decision/` **no puede importar** desde `ejecucion/`, `persistencia/`
ni `conectores/`. La ausencia de esas dependencias es verificable por
inspección estática y sostiene la propiedad de seguridad del sistema.

Toda solicitud de incorporación que introduzca una de esas dependencias
se rechaza sin discusión.

## Secretos

- El archivo `.env` **nunca** se versiona. Se crea a partir de `.env.example`.
- La clave privada de la CA de interceptación nunca se versiona.
- Una credencial publicada en el historial exige **rotar el secreto**;
  suprimir el archivo no basta.
EOF
echo "[4/5] docs/convenciones.md creado."
else
echo "[4/5] docs/convenciones.md ya existe, se conserva."
fi

# ------------------------------------------------------------------------------
# 5. README
# ------------------------------------------------------------------------------
if [ ! -f README.md ]; then
cat > README.md <<'EOF'
# Cronos AI

Sistema SOAR con clasificación asistida por IA y ejecución determinística.

Portafolio de Título · Ingeniería en Informática · DUOC UC, sede Padre Alonso
de Ovalle · Santiago, Chile.

---

## Qué hace

Cronos AI automatiza la respuesta a incidentes de seguridad combinando un
modelo de lenguaje local para la **clasificación** con código convencional para
la **ejecución**. El modelo selecciona dentro de un catálogo cerrado de 25
playbooks; nunca construye comandos ni determina su propio grado de autonomía.

El peor escenario ante una inyección de instrucciones exitosa es la ejecución
de una acción previamente auditada, sobre un activo no excluido, dentro de los
límites de tasa vigentes y reversible.

## Principio arquitectónico

| Capa | Componente | Puede actuar sobre la infraestructura |
| :--- | :--- | :---: |
| Decisión | Ollama, modelo 7B cuantizado, CPU | **No** |
| Validación | Código determinístico, seis comprobaciones | No |
| Ejecución | n8n + Python | **Sí, en exclusiva** |
| Presentación | TEMIS (Django) | No |

## Estructura del repositorio

```
decision/       Prompts y esquemas. Sin dependencias salientes (R1).
validacion/     Catálogo, lista de exclusión y umbrales de tasa.
ejecucion/      Los 25 playbooks con sus rutinas de reversión.
orquestacion/   Flujos de n8n.
persistencia/   Esquema PostgreSQL, encadenamiento de hashes.
conectores/     Directorio, gateway, endpoint y notificación.
argos/          Squid, e2guardian, puente ICAP y CA de interceptación.
temis/          Interfaz web de operación.
infra/          Docker, Wazuh, Tailscale y máquinas virtuales.
pruebas/        Conjuntos etiquetados, casos adversariales y evidencia.
docs/           Documento maestro, documentos derivados y diagramas.
```

## Nodos

| Nodo | Rol |
| :--- | :--- |
| ZEUS | Anfitrión. Solo contenedores. Excluido de toda acción correctiva. |
| HERA | Controlador de dominio. Objetivo de las acciones de identidad. |
| ARGOS | Gateway y punto de aplicación del control DLP. |
| HESTIA | Estación Windows del dominio. |
| APOLO | Estación Linux. |
| ARES | Nodo atacante. Ejecuta Atomic Red Team. |
| TEMIS | Interfaz de operación. Delibera, no ejecuta. |

## Puesta en marcha

Documentada en `docs/derivados/CRO-INS-01_Guia_de_Instalacion.md`.

```bash
cp .env.example .env     # completar los valores
docker compose -f infra/docker/docker-compose.yml up -d
```

## Documentación

El documento de referencia es `docs/maestro/CRONOS_AI_Documento_Maestro.md`.
Los documentos derivados están en `docs/derivados/`.

Ante discrepancia entre el maestro y un documento derivado, **prevalece el
maestro** y el derivado se corrige.

## Equipo

| Integrante | Capa |
| :--- | :--- |
| Nicolás | Infraestructura, red y gateway. Playbooks F4 y F5. |
| Rodrigo | Decisión e inteligencia artificial. Playbooks F2 y F6. |
| Patricio | Orquestación, ejecución y datos. Playbooks F1 y F3. |

Convenciones de trabajo en `docs/convenciones.md`.

## Marco normativo

Ley N.º 21.719 sobre protección y tratamiento de datos personales (Chile).
El mapeo de principios contra controles está en
`docs/derivados/CRO-CMP-01_Matriz_de_Cumplimiento.md`.

## Advertencia

Entorno de laboratorio con fines académicos. Contiene interceptación TLS y
credenciales privilegiadas sobre infraestructura simulada. No desplegar sobre
redes productivas ni sobre equipos de terceros.
EOF
echo "[5/5] README.md creado."
else
echo "[5/5] README.md ya existe, se conserva."
fi

echo
echo "=============================================="
echo " Bootstrap completado."
echo
echo " Siguientes pasos:"
echo "   1. Copiar el documento maestro a docs/maestro/"
echo "   2. Copiar CRO-PRV-01 a docs/derivados/"
echo "   3. git add . && git commit"
echo "   4. Crear la rama develop y proteger main en GitHub"
echo "=============================================="
