# Capa de decisión · Kronos AI

Responsable: Patricio González

## Restricción R1

Este módulo **no puede importar** nada desde `ejecucion/`, `persistencia/` ni
`conectores/`. La ausencia de esas dependencias es lo que hace verificable la
afirmación de que el modelo carece de agencia. Toda solicitud de incorporación
que introduzca una de esas dependencias se rechaza.

## Estructura

    prompts/
      paso1_familia.txt         Prompt del primer paso: elige entre 6 familias
      paso2_plantilla.txt       Plantilla del segundo paso, con marcadores
      paso2/
        Fx_condiciones.txt      Condición de disparo de cada playbook, por familia
        Fx_discriminante.txt    Pregunta que resuelve la confusión típica de esa familia
    esquemas/
      paso1_familia.json        Esquema con enum de las 6 familias
      paso2_playbook.json       Esquema con enum dinámico de candidatos
    mediciones/
      Registro de las pruebas y sus resultados

## Ensamblaje del paso 2

El código construye el prompt combinando cuatro piezas:

    paso2_plantilla.txt
      {{familia}}       ← resultado del paso 1
      {{condiciones}}   ← Fx_condiciones.txt, filtrado por severidad
      {{discriminante}} ← Fx_discriminante.txt
      {{alerta}}        ← payload normalizado del evento

El filtro por severidad se define en `validacion/limites/mapa_severidad.yml` y
lo aplica código determinístico **antes** de invocar al modelo. El `enum` del
esquema se construye solo con los candidatos que sobrevivieron al filtro, de
modo que el modelo no puede devolver un playbook de un nivel no admitido: no
está en el vocabulario.

## Parámetros de inferencia

| Parámetro | Valor | Fundamento |
| :--- | :--- | :--- |
| `model` | qwen2.5:7b-instruct-q4_K_M | 4,91 GiB residentes, 2,87 s por inferencia |
| `temperature` | 0.1 | Consistencia entre ejecuciones |
| `num_predict` | 32 | Un JSON de dos campos no requiere más |
| `format` | esquema con enum | El vocabulario lo garantiza el motor, no el prompt |

## Advertencia para el validador

El modelo puede devolver la confianza en escala 0 a 100 en lugar de 0.0 a 1.0.
El esquema de Ollama respeta `enum` y tipos, pero **no** respeta `minimum` ni
`maximum`. El validador debe normalizar antes de comparar contra el umbral.

Sin esquema estructurado, el modelo además agrega campos no solicitados. El
esquema no es una comodidad: es una garantía.

## Principio de redacción de prompts

Las definiciones de familia y de playbook del catálogo describen **qué es** cada
categoría. Eso sirve para un lector humano, no para clasificar.

Un prompt eficaz declara **cuándo elegir** cada opción: qué debe estar presente
en la alerta para que le corresponda esa acción y no la anterior. Esta diferencia
elevó la precisión del paso 1 de 4/8 a 7/8, y la del paso 2 de 1/5 a 5/5.
