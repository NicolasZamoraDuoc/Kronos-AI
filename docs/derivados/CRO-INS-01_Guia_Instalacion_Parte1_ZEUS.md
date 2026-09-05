# CRO-INS-01 · Guía de Instalación del Stack
## Parte 1 — Sistema base del anfitrión ZEUS

**Proyecto:** Kronos AI · Sistema SOAR con clasificación asistida por IA
**Etapa:** 1 · Cierre `v0.2.0`
**Responsable:** Nicolás Zamora
**Estado:** Ejecutado y verificado

---

## 1. Alcance

Esta parte documenta la instalación del sistema operativo y de la capa base de virtualización y contenedores del equipo anfitrión ZEUS. No cubre el despliegue de servicios de aplicación, que corresponde a las etapas 2 en adelante.

El procedimiento es reproducible: cualquier integrante debería poder reconstruir ZEUS desde cero siguiendo estos pasos.

---

## 2. Hardware del anfitrión

| Componente | Detalle |
| :--- | :--- |
| Placa madre | Gigabyte B550M DS3H |
| Memoria | 30 GiB utilizables |
| Swap | 8 GiB (archivo `/swap.img`) |
| Disco 1 | Kingston SNV2S250G · NVMe · 232,9 G |
| Disco 2 | Kingston SNVS500G · NVMe · 465,8 G |
| Disco 3 | Seagate ST1000LM035 · SATA · 931,5 G |
| Virtualización | AMD-V habilitada (16 hilos con `svm`) |

---

## 3. Sistema operativo

**Versión instalada:** Ubuntu Desktop 26.04 LTS (*Resolute Raccoon*), kernel `7.0.0-30-generic`.

### 3.1 Configuración de firmware previa

Ajustes obligatorios en la UEFI antes de instalar:

| Opción | Valor | Fundamento |
| :--- | :--- | :--- |
| Virtualización (AMD-V / SVM) | Habilitada | Sin ella VirtualBox no puede crear máquinas virtuales. |
| **Secure Boot** | **Deshabilitado** | Con Secure Boot activo los módulos de kernel de VirtualBox no cargan. Alternativa: enrolar una clave MOK, descartada por añadir un paso manual tras cada recompilación. |
| Modo de arranque | UEFI | Coherente con la tabla de particiones GPT. |

### 3.2 Parámetros de instalación

| Parámetro | Valor |
| :--- | :--- |
| Tipo de instalación | Interactiva, normal |
| Disco de destino | `nvme0n1` (232,9 G) — **exclusivamente** |
| Software de terceros | Códecs y controladores instalados |
| Cifrado de disco | **Ninguno** |
| Nombre del equipo | `zeus` |
| Usuario | `kronos` |
| Inicio de sesión automático | Desactivado |
| Zona horaria | Santiago |

> **Sobre la ausencia de cifrado.** ZEUS debe poder reiniciar sin intervención humana. Un disco cifrado con LUKS exigiría escribir una contraseña en cada arranque, lo que impediría la recuperación remota del anfitrión y contradiría el propósito del acceso por red mesh.

### 3.3 Advertencia de BitLocker durante la instalación

El instalador advirtió sobre particiones cifradas con BitLocker presentes en el equipo. La advertencia era pertinente: existían instalaciones previas de Windows en `nvme0n1` y `nvme1n1`.

Ambas se descartaron de forma deliberada. Antes de proceder se verificó en la pantalla de resumen que únicamente `nvme0n1` figurase como modificado, y que el resto de los discos apareciera como *No modificado*.

---

## 4. Distribución de discos

La separación responde a un criterio de rendimiento: el sistema operativo no compite por E/S con la carga de datos del stack.

| Dispositivo | Punto de montaje | Capacidad | Etiqueta | Contenido previsto |
| :--- | :--- | :---: | :--- | :--- |
| `nvme0n1p1` | `/boot/efi` | 1 G | — | Partición de arranque UEFI |
| `nvme0n1p2` | `/` | 231,8 G | — | Sistema operativo |
| `nvme1n1p1` | `/var/lib/docker` | 458 G | `KRONOS_DATA` | Imágenes y volúmenes: Ollama, PostgreSQL, Wazuh, Presidio |
| `sda1` | `/srv/respaldo` | 916 G | `KRONOS_BACKUP` | ISOs, exportaciones de VM, evidencia de escenarios |

### 4.1 Procedimiento aplicado

```bash
# Verificar que ninguna partición esté montada antes de destruirla
lsblk -o NAME,SIZE,FSTYPE,MOUNTPOINT | grep -E 'sda|nvme1n1'

# SSD de datos
sudo wipefs -a /dev/nvme1n1
sudo parted /dev/nvme1n1 --script mklabel gpt mkpart primary ext4 0% 100%
sudo mkfs.ext4 -m 1 -L KRONOS_DATA /dev/nvme1n1p1

# HDD de respaldo
sudo wipefs -a /dev/sda
sudo parted /dev/sda --script mklabel gpt mkpart primary ext4 0% 100%
sudo mkfs.ext4 -m 1 -L KRONOS_BACKUP /dev/sda1

# Puntos de montaje
sudo mkdir -p /var/lib/docker /srv/respaldo

# Montaje permanente por UUID
sudo cp /etc/fstab /etc/fstab.bak
echo "UUID=$(sudo blkid -s UUID -o value /dev/nvme1n1p1)  /var/lib/docker  ext4  defaults,noatime  0  2" | sudo tee -a /etc/fstab
echo "UUID=$(sudo blkid -s UUID -o value /dev/sda1)  /srv/respaldo  ext4  defaults,noatime  0  2" | sudo tee -a /etc/fstab

sudo systemctl daemon-reload
sudo mount -a
sudo chown kronos:kronos /srv/respaldo
```

### 4.2 Decisiones registradas

| Decisión | Fundamento |
| :--- | :--- |
| Montar por **UUID** y no por nombre de dispositivo | Los identificadores `sda` y `nvme1n1` pueden reordenarse entre arranques; el UUID es estable. |
| Opción `-m 1` en `mkfs.ext4` | Reduce del 5 % al 1 % el espacio reservado para el superusuario. En discos de datos recupera unos 23 G en el SSD y 46 G en el HDD. |
| Opción `noatime` en el montaje | Evita escribir la marca de último acceso en cada lectura. Reduce desgaste del SSD y mejora el rendimiento con contenedores. |
| Montar el SSD directamente en `/var/lib/docker` **antes** de instalar Docker | Docker se inicializa ya sobre el disco definitivo. Evita una migración posterior de imágenes y volúmenes. |

### 4.3 UUID asignados

| Partición | UUID |
| :--- | :--- |
| `nvme1n1p1` | `85ca8f19-a3d4-4e03-b887-ef7c1090763c` |
| `sda1` | `f06aaeee-777a-4359-87f5-27fc53f67665` |

---

## 5. Paquetes base

```bash
sudo apt update && sudo apt upgrade -y
sudo apt install -y curl wget git build-essential dkms \
    linux-headers-$(uname -r) net-tools htop gnupg ca-certificates
```

> **Incidencia registrada.** La omisión inicial de este paso provocó el fallo de la instalación de Docker: `curl` no estaba presente, la clave del repositorio no se descargó y `apt update` rechazó el repositorio por firma ausente. Los paquetes `dkms` y `linux-headers` son además condición necesaria para que VirtualBox compile sus módulos.

---

## 6. Docker Engine

Se instala desde el repositorio oficial de Docker y no desde el de Ubuntu, para disponer de la versión vigente.

```bash
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io \
    docker-buildx-plugin docker-compose-plugin

sudo usermod -aG docker $USER
newgrp docker
```

### 6.1 Verificación obtenida

| Elemento | Valor |
| :--- | :--- |
| Docker Engine | 29.7.2 (build a7dcaa6) |
| Docker Compose | v5.5.0 |
| Storage Driver | overlayfs |
| Cgroup Driver / Version | systemd / **2** |
| **Docker Root Dir** | **`/var/lib/docker`** sobre `nvme1n1p1` |
| Prueba funcional | `docker run --rm hello-world` ejecutado correctamente |

> Ubuntu 26.04 eliminó el soporte de cgroup v1. Docker opera sobre cgroup v2, de modo que la retirada no afecta al despliegue. Se documenta porque invalida los procedimientos de configuración de contenedores anteriores a esta versión.

---

## 7. VirtualBox

### 7.1 Contexto del riesgo RT-04

La matriz de riesgos identifica como riesgo técnico de exposición alta la incompatibilidad de la plataforma de virtualización con el kernel del anfitrión. El contexto verificado al momento de la instalación era el siguiente:

- Ubuntu 26.04 LTS incorpora kernel 7.0.
- Existe un defecto reportado de compilación de módulos con VirtualBox 7.2.7 de Oracle sobre kernel 7.0.
- VirtualBox 7.2.8 incorporó el soporte inicial para kernel 7.0.
- Oracle no publica paquetes `.deb` para la serie 26.04; solo ofrece el instalador genérico `.run`.
- El repositorio de Ubuntu 26.04 provee la versión 7.2.6 en `multiverse`.

Ante ese escenario se optó por probar primero el paquete de la distribución, reservando el instalador de Oracle como plan de contingencia.

```bash
sudo apt install -y virtualbox virtualbox-ext-pack
sudo usermod -aG vboxusers $USER
```

### 7.2 Resultado

**El paquete 7.2.6 de Ubuntu compila y carga correctamente sobre kernel 7.0.** Presumiblemente el mantenedor de la distribución aplicó parches propios que no están presentes en la versión equivalente de Oracle.

```
$ lsmod | grep vbox
vboxnetadp    28672   0
vboxnetflt    40960   0
vboxdrv      741376   2 vboxnetadp,vboxnetflt

$ dkms status
virtualbox/7.2.6, 7.0.0-14-generic, x86_64: installed
virtualbox/7.2.6, 7.0.0-30-generic, x86_64: installed
```

DKMS mantiene los módulos compilados para dos versiones de kernel, de modo que una actualización del kernel no dejará VirtualBox inoperativo.

### 7.3 Observaciones no bloqueantes

| Observación | Interpretación |
| :--- | :--- |
| `Unit vboxdrv.service could not be found` | El paquete de la distribución gestiona los módulos por DKMS y no crea ese servicio, a diferencia del instalador de Oracle. La verificación válida es `lsmod`. |
| Extension Pack `VNC` marcado como `Usable: false` | Componente empaquetado por Debian con una cadena de versión sin sustituir. No se emplea en el proyecto. El Extension Pack de Oracle, que sí es necesario, figura como `Usable: true`. |

### 7.4 Actualización del riesgo RT-04

El riesgo se considera **materializado y resuelto**. La mitigación efectiva difiere de la planificada: no fue necesario recurrir al instalador de Oracle, y la recomendación original de instalar desde el sitio del fabricante resultó inaplicable por ausencia de paquetes para esta versión de Ubuntu.

---

## 8. Red mesh Tailscale

```bash
curl -fsSL https://tailscale.com/install.sh | sudo sh
sudo tailscale up --hostname=zeus
```

### 8.1 Incidencia: límite de usuarios del dominio institucional

El primer intento de autenticación empleó una cuenta de correo institucional y fue rechazado con el mensaje *Reached user limit*.

**Causa:** Tailscale agrupa automáticamente en una misma red a todos los usuarios que comparten dominio de correo. La red asociada al dominio institucional ya había alcanzado el límite del plan gratuito por usuarios ajenos al proyecto.

**Resolución:** autenticar con una cuenta personal de dominio genérico, que obtiene una red aislada y propia.

```bash
sudo tailscale logout
sudo tailscale up --hostname=zeus
```

> **Lección aplicable a las etapas siguientes.** Los nodos HERA, HESTIA, APOLO y ARES deben unirse a esta misma red mediante invitación desde la cuenta administradora. No deben autenticarse con cuentas institucionales.

### 8.2 Estado resultante

| Nodo | Dirección en la malla | Sistema | Estado |
| :--- | :--- | :--- | :--- |
| `zeus` | **`100.114.7.65`** | Linux | Conectado |

Versión de Tailscale: 1.102.3.

> El rango `100.64.0.0/10` constituye la categoría **E2** de la lista de exclusión: es el canal por el cual se ejecuta toda reversión, y ningún playbook puede actuar sobre él.

---

## 9. Verificación de cierre de la etapa

| # | Comprobación | Comando | Resultado |
| :---: | :--- | :--- | :--- |
| 1 | Versión del sistema | `lsb_release -a` | Ubuntu 26.04 LTS · resolute |
| 2 | Kernel | `uname -r` | 7.0.0-30-generic |
| 3 | Memoria | `free -h` | 30 GiB + 8 GiB swap |
| 4 | Virtualización por hardware | `egrep -c '(vmx\|svm)' /proc/cpuinfo` | 16 |
| 5 | Secure Boot | `mokutil --sb-state` | disabled |
| 6 | Discos montados | `df -h /var/lib/docker /srv/respaldo` | 458 G y 916 G |
| 7 | Docker operativo | `docker run --rm hello-world` | Correcto |
| 8 | Docker sobre el disco previsto | `docker info \| grep "Docker Root Dir"` | `/var/lib/docker` |
| 9 | Módulos de VirtualBox | `lsmod \| grep vbox` | Tres módulos cargados |
| 10 | Malla operativa | `tailscale status` | `zeus` en `100.114.7.65` |

---

## 10. Pendientes derivados

| # | Pendiente | Etapa |
| :---: | :--- | :---: |
| 1 | Aplicar las 123 actualizaciones pendientes (`sudo apt upgrade`) y depurar kernels antiguos (`sudo apt autoremove`). | 1 (cierre) |
| 2 | Medir el consumo real de memoria bajo carga y sustituir las estimaciones del documento maestro por valores medidos. | 3 en adelante |
| 3 | Unir HERA, HESTIA, APOLO y ARES a la malla con la cuenta administradora. | 3 |
| 4 | Registrar la dirección `100.114.7.65` en la lista de exclusión, categoría E1. | 5 |
| 5 | Actualizar el documento maestro: la versión adoptada es 26.04 y no 24.04. | 1 (cierre) |

---

## 11. Correcciones al documento maestro

Esta etapa produce dos correcciones que deben incorporarse al Documento Maestro v2.0:

| Sección | Contenido anterior | Corrección |
| :--- | :--- | :--- |
| §11.7 · Sistema operativo del anfitrión | Ubuntu 24.04 LTS, con las afirmaciones sobre kernel 7.0 y VirtualBox marcadas como no verificadas. | **Ubuntu 26.04 LTS con kernel 7.0.** Las afirmaciones quedan verificadas contra fuentes y contra la instalación real. |
| §17.2 · RT-04 | Mitigación: instalar VirtualBox desde el sitio oficial de Oracle. | **Mitigación efectiva: usar el paquete `virtualbox` del repositorio `multiverse` de Ubuntu 26.04.** Oracle no publica paquetes `.deb` para esta versión, y su serie 7.2.7 presenta un defecto documentado sobre kernel 7.0. |

---

*Fin de la Parte 1 · CRO-INS-01*
