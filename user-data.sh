#!/bin/bash

echo "=== VPN Server Setup Started at $(date) ==="

hostnamectl set-hostname "${instance_name}"
echo "127.0.0.1 ${instance_name}" >> /etc/hosts

sysctl -w net.ipv4.ip_forward=1
echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf

echo "=== Installing packages ==="
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y openvpn easy-rsa awscli ufw net-tools

SSM_SERVICE="snap.amazon-ssm-agent.amazon-ssm-agent"
if ! snap list amazon-ssm-agent >/dev/null 2>&1; then
    snap install amazon-ssm-agent --classic
fi
systemctl enable $SSM_SERVICE 2>/dev/null
systemctl start $SSM_SERVICE 2>/dev/null

TOKEN=$(curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
INSTANCE_ID=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/instance-id)

aws ec2 associate-address --instance-id $INSTANCE_ID --allocation-id ${eip_allocation_id} --region ${region}
sleep 5
PUBLIC_IP=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/public-ipv4)

mkdir -p /etc/openvpn/server /etc/openvpn/client /var/log/openvpn

if [ -d /usr/share/easy-rsa ]; then
    cp -r /usr/share/easy-rsa /etc/openvpn/easy-rsa
else
    cd /tmp && curl -L https://github.com/OpenVPN/easy-rsa/releases/download/v3.1.7/EasyRSA-3.1.7.tgz -o easyrsa.tgz
    tar xzf easyrsa.tgz && mkdir -p /etc/openvpn/easy-rsa && cp -r EasyRSA-3.1.7/* /etc/openvpn/easy-rsa/
fi
cd /etc/openvpn/easy-rsa

cat > vars << EOF
set_var EASYRSA_REQ_COUNTRY    "US"
set_var EASYRSA_REQ_PROVINCE   "CA"
set_var EASYRSA_REQ_CITY       "San Francisco"
set_var EASYRSA_REQ_ORG        "PWP-VPN"
set_var EASYRSA_REQ_EMAIL      "admin@pwp-vpn.local"
set_var EASYRSA_REQ_OU         "VPN"
set_var EASYRSA_KEY_SIZE       2048
set_var EASYRSA_ALGO           ec
set_var EASYRSA_DIGEST         sha512
set_var EASYRSA_CA_EXPIRE      3650
set_var EASYRSA_CERT_EXPIRE    3650
set_var EASYRSA_BATCH          yes
EOF

export EASYRSA_BATCH=1

if aws s3 ls s3://${bucket_name}/pki/ca.crt --region ${region} 2>/dev/null; then
    echo "Downloading existing certificates"
    aws s3 sync s3://${bucket_name}/pki/ /etc/openvpn/easy-rsa/pki/ --region ${region}
else
    echo "Creating new certificates"
    ./easyrsa init-pki
    ./easyrsa build-ca nopass
    ./easyrsa build-server-full server nopass
    openvpn --genkey secret pki/ta.key
    aws s3 sync /etc/openvpn/easy-rsa/pki/ s3://${bucket_name}/pki/ --region ${region}
fi

# Ensure OpenVPN can read key/cert/dh/ta files
chown root:nogroup /etc/openvpn/easy-rsa/pki/*.key /etc/openvpn/easy-rsa/pki/*.crt /etc/openvpn/easy-rsa/pki/ta.key
chmod 640 /etc/openvpn/easy-rsa/pki/*.key /etc/openvpn/easy-rsa/pki/*.crt /etc/openvpn/easy-rsa/pki/ta.key
# Also fix permissions for server cert and key
chown root:nogroup /etc/openvpn/easy-rsa/pki/issued/server.crt /etc/openvpn/easy-rsa/pki/private/server.key
chmod 640 /etc/openvpn/easy-rsa/pki/issued/server.crt /etc/openvpn/easy-rsa/pki/private/server.key
# Also fix permissions for client cert and key
chown root:nogroup /etc/openvpn/easy-rsa/pki/issued/client.crt /etc/openvpn/easy-rsa/pki/private/client.key
chmod 640 /etc/openvpn/easy-rsa/pki/issued/client.crt /etc/openvpn/easy-rsa/pki/private/client.key
# Set directory permissions for issued and private
chmod 750 /etc/openvpn/easy-rsa/pki/issued /etc/openvpn/easy-rsa/pki/private

cat > /etc/openvpn/server-udp.conf << EOF
port 1194
proto udp4
dev tun
ca /etc/openvpn/easy-rsa/pki/ca.crt
cert /etc/openvpn/easy-rsa/pki/issued/server.crt
key /etc/openvpn/easy-rsa/pki/private/server.key
dh none
tls-crypt /etc/openvpn/easy-rsa/pki/ta.key
topology subnet
server 10.8.0.0 255.255.255.0
ifconfig-pool-persist /var/log/openvpn/ipp.txt
push "redirect-gateway def1 bypass-dhcp"
push "dhcp-option DNS 1.1.1.1"
push "dhcp-option DNS 8.8.8.8"
keepalive 10 120
cipher AES-256-GCM
auth SHA256
user nobody
group nogroup
persist-key
persist-tun
status /var/log/openvpn/openvpn-status.log
log-append /var/log/openvpn/openvpn.log
verb 3
explicit-exit-notify 1
EOF

cat > /etc/openvpn/server-tcp.conf << EOF
port 443
proto tcp4
dev tun
ca /etc/openvpn/easy-rsa/pki/ca.crt
cert /etc/openvpn/easy-rsa/pki/issued/server.crt
key /etc/openvpn/easy-rsa/pki/private/server.key
dh none
tls-crypt /etc/openvpn/easy-rsa/pki/ta.key
topology subnet
server 10.9.0.0 255.255.255.0
ifconfig-pool-persist /var/log/openvpn/ipp-tcp.txt
push "redirect-gateway def1 bypass-dhcp"
push "dhcp-option DNS 1.1.1.1"
push "dhcp-option DNS 8.8.8.8"
keepalive 10 120
cipher AES-256-GCM
auth SHA256
user nobody
group nogroup
persist-key
persist-tun
status /var/log/openvpn/openvpn-tcp-status.log
log-append /var/log/openvpn/openvpn-tcp.log
verb 3
EOF

cd /etc/openvpn/easy-rsa
if [ ! -f pki/issued/client.crt ]; then
    ./easyrsa build-client-full client nopass
    aws s3 sync /etc/openvpn/easy-rsa/pki/ s3://${bucket_name}/pki/ --region ${region}
fi

cat > /etc/openvpn/client/client-udp.ovpn << EOF
client
dev tun
proto udp
remote $PUBLIC_IP 1194
resolv-retry infinite
nobind
persist-key
persist-tun
cipher AES-256-GCM
auth SHA256
verb 3
<ca>
$(cat /etc/openvpn/easy-rsa/pki/ca.crt)
</ca>
<cert>
$(sed -n '/BEGIN CERTIFICATE/,/END CERTIFICATE/p' /etc/openvpn/easy-rsa/pki/issued/client.crt)
</cert>
<key>
$(cat /etc/openvpn/easy-rsa/pki/private/client.key)
</key>
<tls-crypt>
$(cat /etc/openvpn/easy-rsa/pki/ta.key)
</tls-crypt>
EOF

cat > /etc/openvpn/client/client-tcp.ovpn << EOF
client
dev tun
proto tcp
remote $PUBLIC_IP 443
resolv-retry infinite
nobind
persist-key
persist-tun
cipher AES-256-GCM
auth SHA256
verb 3
<ca>
$(cat /etc/openvpn/easy-rsa/pki/ca.crt)
</ca>
<cert>
$(sed -n '/BEGIN CERTIFICATE/,/END CERTIFICATE/p' /etc/openvpn/easy-rsa/pki/issued/client.crt)
</cert>
<key>
$(cat /etc/openvpn/easy-rsa/pki/private/client.key)
</key>
<tls-crypt>
$(cat /etc/openvpn/easy-rsa/pki/ta.key)
</tls-crypt>
EOF

aws s3 cp /etc/openvpn/client/client-udp.ovpn s3://${bucket_name}/client-udp.ovpn --region ${region}
aws s3 cp /etc/openvpn/client/client-tcp.ovpn s3://${bucket_name}/client-tcp.ovpn --region ${region}

echo 'net.ipv4.ip_forward = 1' >> /etc/sysctl.conf
sysctl -p
INTERFACE=$(ip route | grep default | awk '{print $5}')
ufw --force reset
ufw default deny incoming
ufw default allow outgoing
ufw default allow forward
ufw allow 1194/udp
ufw allow 443/tcp
ufw allow 22/tcp

cat >> /etc/ufw/before.rules << EOF

*nat
:POSTROUTING ACCEPT [0:0]
-A POSTROUTING -s 10.8.0.0/24 -o $INTERFACE -j MASQUERADE
-A POSTROUTING -s 10.9.0.0/24 -o $INTERFACE -j MASQUERADE
COMMIT
EOF

sed -i 's/#net\/ipv4\/ip_forward=1/net\/ipv4\/ip_forward=1/' /etc/ufw/sysctl.conf
ufw --force enable

systemctl stop openvpn@server 2>/dev/null || true
systemctl stop openvpn 2>/dev/null || true
pkill openvpn 2>/dev/null || true
sleep 2

systemctl enable openvpn@server-udp
systemctl start openvpn@server-udp
systemctl enable openvpn@server-tcp
systemctl start openvpn@server-tcp

# Download and install the VPN idle shutdown script as a cron job
aws s3 cp s3://${bucket_name}/vpn-idle-shutdown.sh /usr/local/bin/vpn-idle-shutdown.sh --region ${region}
chmod +x /usr/local/bin/vpn-idle-shutdown.sh
if ! grep -q 'vpn-idle-shutdown.sh' /etc/crontab; then
    echo "* * * * * root /usr/local/bin/vpn-idle-shutdown.sh" >> /etc/crontab
fi

# Update SSM parameter with last ready time
aws ssm put-parameter \
    --name "/pwp-vpn/last-ready" \
    --type String \
    --value "$(date -u +'%Y-%m-%dT%H:%M:%SZ')" \
    --overwrite \
    --region ${region}
