#!/usr/bin/env bash
# HERA · Estructura del directorio: OUs, cuentas y grupos
# Ejecutar DENTRO de HERA, tras provisionar el dominio.
# Las contrasenas se solicitan de forma interactiva.
set -euo pipefail

# --- Unidades organizativas ---
sudo samba-tool ou create "OU=Kronos,DC=kronos,DC=local"
sudo samba-tool ou create "OU=Usuarios,OU=Kronos,DC=kronos,DC=local"
sudo samba-tool ou create "OU=Contabilidad,OU=Usuarios,OU=Kronos,DC=kronos,DC=local"
sudo samba-tool ou create "OU=Operaciones,OU=Usuarios,OU=Kronos,DC=kronos,DC=local"
sudo samba-tool ou create "OU=Servicios,OU=Kronos,DC=kronos,DC=local"
sudo samba-tool ou create "OU=Equipos,OU=Kronos,DC=kronos,DC=local"

# --- Cuentas de servicio: exclusion categoria E3 ---
sudo samba-tool user create svc-kronos-lectura \
  --userou="OU=Servicios,OU=Kronos" \
  --description="Kronos AI: consultas de enriquecimiento, solo lectura"
sudo samba-tool user create svc-kronos-identidad \
  --userou="OU=Servicios,OU=Kronos" \
  --description="Kronos AI: deshabilitar cuentas y revocar grupos"
sudo samba-tool user setexpiry svc-kronos-lectura --noexpiry
sudo samba-tool user setexpiry svc-kronos-identidad --noexpiry

# --- Cuenta break-glass: exclusion categoria E4 ---
sudo samba-tool user create admin-emergencia \
  --userou="OU=Servicios,OU=Kronos" \
  --description="Break-glass: recuperacion manual ante fallo de la automatizacion"
sudo samba-tool user setexpiry admin-emergencia --noexpiry
sudo samba-tool group addmembers "Domain Admins" admin-emergencia

# --- Grupos ---
sudo samba-tool group add "Kronos-Soporte" --groupou="OU=Kronos" \
  --description="Grupo privilegiado de prueba para la familia F3"
sudo samba-tool group add "Kronos-Analistas" --groupou="OU=Kronos" \
  --description="Analistas SOC: exclusion categoria E6"

# --- Usuarios de prueba ---
for u in jperez:Contabilidad mgonzalez:Contabilidad rlopez:Contabilidad \
         csoto:Operaciones amunoz:Operaciones; do
  USER="${u%%:*}"; OU="${u##*:}"
  sudo samba-tool user create "$USER" \
    --userou="OU=$OU,OU=Usuarios,OU=Kronos" \
    --given-name="${USER^}" --surname="Prueba" \
    --mail-address="$USER@kronos.local" \
    --description="Usuario de prueba, OU $OU"
  sudo samba-tool user setexpiry "$USER" --noexpiry
done

# --- Analistas: exclusion categoria E6 ---
for a in analista1 analista2; do
  sudo samba-tool user create "$a" \
    --userou="OU=Servicios,OU=Kronos" \
    --mail-address="$a@kronos.local" \
    --description="Analista SOC de turno: exclusion categoria E6"
  sudo samba-tool user setexpiry "$a" --noexpiry
  sudo samba-tool group addmembers "Kronos-Analistas" "$a"
done

sudo samba-tool group addmembers "Kronos-Soporte" csoto

# --- Contacto fuera de banda: condicion del Nivel 2 ---
# Sin este atributo, las acciones de Nivel 2 derivan a MANUAL_TRIAGE
# porque no puede cumplirse la obligacion de notificacion al titular.
> /tmp/oob.ldif
for u in jperez mgonzalez rlopez csoto amunoz; do
  DN=$(sudo samba-tool user show "$u" | grep "^distinguishedName:" | cut -d' ' -f2-)
  cat >> /tmp/oob.ldif << LDIF
dn: $DN
changetype: modify
add: otherMailbox
otherMailbox: $u.personal@fueradebanda.local
-

LDIF
done
sudo ldbmodify -H /var/lib/samba/private/sam.ldb /tmp/oob.ldif
rm -f /tmp/oob.ldif

echo "Estructura creada."
sudo samba-tool user list
