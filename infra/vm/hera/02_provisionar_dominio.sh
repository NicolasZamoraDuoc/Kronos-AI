#!/usr/bin/env bash
# HERA · Provision del dominio Samba AD DC
# Ejecutar DENTRO de HERA, tras instalar Ubuntu Server
set -euo pipefail

sudo hostnamectl set-hostname hera.kronos.local

sudo tee /etc/hosts > /dev/null << 'HOSTS'
127.0.0.1       localhost
10.10.10.10     hera.kronos.local hera

::1     localhost ip6-localhost ip6-loopback
HOSTS

# Liberar el puerto 53 para el DNS de Samba
sudo systemctl disable --now systemd-resolved
sudo chattr -i /etc/resolv.conf 2>/dev/null || true
sudo rm -f /etc/resolv.conf
sudo tee /etc/resolv.conf > /dev/null << 'RESOLV'
nameserver 127.0.0.1
search kronos.local
RESOLV

sudo DEBIAN_FRONTEND=noninteractive apt install -y \
  samba smbclient winbind libpam-winbind libnss-winbind \
  krb5-user krb5-config dnsutils chrony ldb-tools

sudo systemctl disable --now smbd nmbd winbind 2>/dev/null || true
sudo systemctl unmask samba-ad-dc
sudo mv /etc/samba/smb.conf /etc/samba/smb.conf.original 2>/dev/null || true

echo "Ejecutar manualmente para no exponer la clave en el historial:"
echo "sudo samba-tool domain provision --realm=KRONOS.LOCAL --domain=KRONOS \\"
echo "  --server-role=dc --dns-backend=SAMBA_INTERNAL --use-rfc2307 --adminpass='...'"
echo ""
echo "Despues:"
echo "sudo cp /var/lib/samba/private/krb5.conf /etc/krb5.conf"
echo "sudo sed -i '/\\[global\\]/a\\        dns forwarder = 8.8.8.8' /etc/samba/smb.conf"
echo "sudo sed -i '/dns forwarder = 127.0.0.1/d' /etc/samba/smb.conf"
echo "sudo systemctl enable --now samba-ad-dc chrony"
echo "sudo samba-tool user setexpiry Administrator --noexpiry"
