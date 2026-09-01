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
