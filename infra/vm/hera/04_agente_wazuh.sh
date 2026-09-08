#!/usr/bin/env bash
# HERA · Instalacion del agente de Wazuh
# Ejecutar DENTRO de HERA, tras provisionar el dominio.
set -euo pipefail

MANAGER="100.114.7.65"   # interfaz de Tailscale de ZEUS

# --- Repositorio de Wazuh ---
curl -sO https://packages.wazuh.com/key/GPG-KEY-WAZUH
sudo gpg --no-default-keyring \
  --keyring gnupg-ring:/usr/share/keyrings/wazuh.gpg --import GPG-KEY-WAZUH
sudo chmod 644 /usr/share/keyrings/wazuh.gpg
rm -f GPG-KEY-WAZUH

echo "deb [signed-by=/usr/share/keyrings/wazuh.gpg] https://packages.wazuh.com/4.x/apt/ stable main" \
  | sudo tee /etc/apt/sources.list.d/wazuh.list

sudo apt update
sudo WAZUH_MANAGER="$MANAGER" WAZUH_AGENT_NAME='HERA' apt install -y wazuh-agent

# --- Registro del agente ---
#
# IMPORTANTE: registrar SIEMPRE con IP 'any', no con la IP del nodo.
#
# La red NAT de VirtualBox aplica traduccion de direcciones: el manager
# recibe los mensajes desde la IP del anfitrion y no desde la del agente.
# Si el agente se registra con su IP real, el manager rechaza sus mensajes
# con el error 1213 "Cannot find the ID of the agent".
#
# En ZEUS:
#   docker exec -it wazuh-wazuh.manager-1 /var/ossec/bin/manage_agents
#     A  ->  nombre: HERA  ->  IP: any  ->  confirmar
#     E  ->  ID asignado   ->  copiar la clave
#     Q
#
# Luego, aqui:
#   sudo systemctl stop wazuh-agent
#   sudo /var/ossec/bin/manage_agents -i "<CLAVE>"

# --- Desactivar el re-registro automatico ---
# Sin esto el agente intenta reinscribirse cada 10 s, el manager lo rechaza
# por nombre duplicado, y el ciclo no termina nunca.
sudo sed -i '/<enrollment>/,/<\/enrollment>/d' /var/ossec/etc/ossec.conf

sudo systemctl enable --now wazuh-agent
sleep 20
sudo tail -6 /var/ossec/logs/ossec.log

echo ""
echo "Verificar desde ZEUS:"
echo "  docker exec wazuh-wazuh.manager-1 /var/ossec/bin/agent_control -l"
echo "El agente debe figurar como Active."
