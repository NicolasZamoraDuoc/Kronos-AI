# Comparación de modelos y efecto del prompt

**Fecha:** 2026-09-05 · **Responsable:** Patricio González
**Entorno:** ZEUS · Ubuntu 26.04 LTS · Ollama 0.33.3 · inferencia sobre CPU, sin GPU

---

## 1. Modelos evaluados

| Modelo | Tamaño en disco | Memoria residente | Sobre la base |
| :--- | :---: | :---: | :---: |
| Contenedor sin modelo cargado | — | 273 MiB | — |
| `qwen2.5:7b-instruct-q4_K_M` | 4,7 GB | **4,91 GiB** | +4,64 GiB |
| `llama3.1:8b-instruct-q4_K_M` | 4,9 GB | **5,42 GiB** | +5,15 GiB |

Medición realizada descargando el modelo previo con `ollama stop` antes de cargar
el siguiente, para evitar que ambos coexistieran en memoria.

**Comparación con la estimación documentada:** el Documento Maestro estima 4,5 GB
para Ollama. La medición de qwen2.5 (4,91 GiB) queda un 9 % por encima; la de
llama3.1 (5,42 GiB) un 20 % por encima. Ambas dentro de un margen manejable, pero
la estimación debe sustituirse por el valor medido.

---

## 2. Conjunto de comparación

Ocho casos construidos a mano, uno por familia más dos deliberadamente ambiguos.

**No es el conjunto de validación.** Es una prueba exploratoria previa, cuyo
propósito era decidir si continuar con este enfoque, no medir desempeño.

---

## 3. Resultados

| Modelo | Prompt A (etiquetas de catálogo) | Prompt B (definiciones operativas) |
| :--- | :---: | :---: |
| qwen2.5 7B | 4 de 8 · 50 % | **7 de 8 · 88 %** |
| llama3.1 8B | 4 de 8 · 50 % | **8 de 8 · 100 %** |

**Latencia media:** 4,20 s (qwen) y 4,25 s (llama). Sin diferencia significativa.

**Latencia por inferencia con modelo residente:** 2,87 s medidos con prompt de
tamaño realista, frente a los 3 a 8 s estimados en el Documento Maestro.

---

## 4. Hallazgo principal

Ambos modelos duplicaron su precisión sin cambiar de modelo, sin reentrenar y sin
más recursos. La única variable modificada fue el texto que describe las seis
familias.

> **La variable crítica es el prompt, no el modelo.** Probar cinco modelos
> distintos con el prompt A habría dejado el desempeño en torno al 50 %.

---

## 5. Diagnóstico de los fallos del prompt A

| Patrón observado | Evidencia |
| :--- | :--- |
| Sesgo hacia F1 ante la duda | F1 apareció en cinco de los ocho fallos. Es la primera opción de la lista, y el modelo la elige cuando no tiene criterio para decidir. |
| F6 nunca se eligió | "Integridad y configuración" resulta demasiado abstracto frente a "código malicioso". El modelo no reconoce que una clave de registro o una tarea programada son mecanismos de persistencia. |
| Confusión F2 contra F6 | Ambos modelos clasificaron persistencia como código malicioso, porque el binario involucrado es malicioso. El criterio de decisión no estaba explícito. |

---

## 6. Qué corrigió el prompt B

1. **Definición por comportamiento observable** en lugar de etiqueta de catálogo.
   "F2: un proceso ejecutándose ahora" en lugar de "F2: código malicioso".

2. **Regla de desempate explícita** para el conflicto F2 contra F6: *"una tarea
   programada o una clave de registro son F6, aunque el binario sea malicioso"*.

3. **Advertencia contra el sesgo de posición**: *"no uses F1 solo porque aparezca
   un nombre de cuenta"*.

---

## 7. Consecuencia para la documentación

Las descripciones de familia de CRO-CAT-01 están escritas para que un lector
humano comprenda el diseño. Son insuficientes como instrucción operativa para el
clasificador.

El proyecto debe mantener **dos versiones** de las definiciones de familia: la
del catálogo, orientada a la comprensión, y la del prompt, orientada a la
clasificación. Ambas versionadas, con la correspondencia entre ellas documentada.

---

## 8. Hallazgo secundario: escala de confianza

El esquema estructurado de Ollama respeta `enum` y los tipos declarados, pero
**no respeta** `minimum` ni `maximum`. Sin aclaración explícita en el prompt, el
modelo devolvió `95` en lugar de `0.95`.

El validador determinístico debe normalizar el valor antes de compararlo contra
el umbral:

```python
c = float(respuesta["confianza"])
if c > 1.0:
    c = c / 100.0
```

Es un ejemplo concreto de por qué existe la capa de validación determinística: el
modelo cumple el esquema declarado y aun así entrega un valor inutilizable.

---

## 9. Advertencia metodológica

Ocho casos no permiten distinguir 88 % de 100 %: la diferencia es un único caso,
y precisamente el ambiguo (una cuenta de servicio autenticando desde una estación
de trabajo, que admite lectura como F1 por uso indebido de credenciales, o como
F3 por cuenta de servicio operando fuera de su función).

**La elección definitiva de modelo debe hacerse contra los 50 casos de la
partición de desarrollo del conjunto KRO-SET-01.** Hasta entonces, esta
comparación es exploratoria y no concluyente.

---

## 10. Estado de la decisión

**Modelo provisional:** `qwen2.5:7b-instruct-q4_K_M`.

Fundamento provisional: consume 0,51 GiB menos de memoria residente que la
alternativa, con latencia equivalente y una diferencia de precisión que la
muestra actual no permite considerar significativa. Ese medio gigabyte proviene
del margen disponible para Wazuh, PostgreSQL y el resto del stack.

La decisión se revisará tras medir sobre la partición de desarrollo. Si la
diferencia se confirma sobre 50 casos, el costo de memoria adicional estaría
justificado.

---

## 11. Configuración de inferencia adoptada

| Parámetro | Valor | Fundamento |
| :--- | :--- | :--- |
| `temperature` | 0.1 | Consistencia entre ejecuciones sobre creatividad. Tres ejecuciones del mismo caso devolvieron resultados idénticos. |
| `num_predict` | 32 | Un JSON de dos campos no requiere más. Evita divagación. |
| `format` | Esquema con `enum` | El vocabulario de familias lo garantiza el motor, no el prompt. |
| `OLLAMA_NUM_PARALLEL` | 1 | Sobre CPU no existe paralelismo efectivo. |
| `OLLAMA_MAX_LOADED_MODELS` | 1 | Un solo modelo residente en memoria. |
| `OLLAMA_KEEP_ALIVE` | 24h | Evita recargar el modelo tras inactividad, lo que añadiría latencia a la primera inferencia. |
