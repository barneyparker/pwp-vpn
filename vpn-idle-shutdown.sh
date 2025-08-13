#!/bin/bash
# vpn-idle-shutdown.sh
# Checks for VPN connections and scales ASG to 0 if idle for 5 consecutive minutes.

TMP_FILE="/tmp/vpn_no_conn_count.txt"


# Get the server's primary IP
SERVER_IP=$(hostname -I | awk '{print $1}')
# Count UDP VPN clients using OpenVPN status file
CONNECTIONS=$(grep -c '^client,' /var/log/openvpn/openvpn-status.log 2>/dev/null | tr -d '[:space:]')
CONNECTIONS=$${CONNECTIONS:-0}

# If there are connections, reset the counter and exit
if [[ $CONNECTIONS -gt 0 ]]; then
  echo 0 > "$TMP_FILE"
  exit 0
fi

# If no connections found, assume we're at 0 and if there is a count file obtain the current count from there
COUNT=0
if [[ -f "$TMP_FILE" ]]; then
  COUNT=$(cat "$TMP_FILE")
fi

# Increment the counter and write it back
COUNT=$((COUNT + 1))
echo $COUNT > "$TMP_FILE"

# If the count reaches 5, scale down the ASG
if [[ $COUNT -ge 5 ]]; then
  aws autoscaling update-auto-scaling-group \
    --auto-scaling-group-name "${asg_name}" \
    --desired-capacity 0 \
    --region "${region}"
  echo 0 > "$TMP_FILE" # Reset after scaling down
fi
