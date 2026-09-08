#!/usr/bin/env bash
# HERA · Controlador de dominio · Creacion de la maquina virtual
# Ejecutar en ZEUS. Requiere el ISO en /media/respaldo/isos/
set -euo pipefail

ISO="/media/respaldo/isos/ubuntu-24.04.3-live-server-amd64.iso"
BASE="/media/respaldo/vms"

VBoxManage natnetwork add --netname KronosNet \
  --network "10.10.10.0/24" --enable --dhcp off 2>/dev/null || true

VBoxManage natnetwork modify --netname KronosNet \
  --port-forward-4 "ssh-hera:tcp:[127.0.0.1]:2222:[10.10.10.10]:22" 2>/dev/null || true

VBoxManage createvm --name HERA --ostype Ubuntu_64 --basefolder "$BASE" --register

VBoxManage modifyvm HERA \
  --memory 2048 --cpus 2 \
  --nic1 natnetwork --nat-network1 KronosNet \
  --graphicscontroller vmsvga --vram 16 \
  --boot1 dvd --boot2 disk

VBoxManage createhd --filename "$BASE/HERA/HERA.vdi" --size 30000 --format VDI
VBoxManage storagectl HERA --name "SATA" --add sata --controller IntelAhci
VBoxManage storageattach HERA --storagectl "SATA" --port 0 --device 0 \
  --type hdd --medium "$BASE/HERA/HERA.vdi"
VBoxManage storagectl HERA --name "IDE" --add ide
VBoxManage storageattach HERA --storagectl "IDE" --port 0 --device 0 \
  --type dvddrive --medium "$ISO"

echo "VM creada. Arrancar con: VBoxManage startvm HERA --type gui"
echo "Red manual en el instalador: 10.10.10.10/24, gw 10.10.10.1, dns 8.8.8.8"
echo "Hostname: hera · Usuario: kronos · Instalar OpenSSH · Sin LVM"
