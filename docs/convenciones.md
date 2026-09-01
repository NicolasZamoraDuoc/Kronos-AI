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
