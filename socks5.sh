#!/bin/bash

# Check if both arguments are provided or ask for them
if [ $# -ne 2 ]; then
    echo -e "Please enter the username for the socks5 proxy:"
    read username
    echo -e "Please enter the password for the socks5 proxy:"
    read -s password
else
    # Assign arguments to variables
    username=$1
    password=$2
fi

# Update repositories
apt update -y

# Install dante-server
apt install dante-server -y

# Get the name of the network interface
interface=$(ip -o -4 route show to default | awk '{print $5}')

# Create the configuration file
bash -c 'cat <<EOF > /etc/danted.conf
logoutput: syslog
internal: 0.0.0.0 port = 1080
external: '$interface'
clientmethod: none
socksmethod: username
user.privileged: root
user.notprivileged: nobody
client pass {
    from: 0.0.0.0/0 to: 0.0.0.0/0
    log: connect disconnect error
}
socks pass {
    from: 0.0.0.0/0 to: 0.0.0.0/0
    log: connect disconnect error
}
EOF'

# Add user with password
useradd --shell /usr/sbin/nologin $username
echo "$username:$password" | chpasswd

# Check if UFW is active and open port 1080 if needed
if ufw status | grep -q "Status: active"; then
    ufw allow 1080/tcp
fi

# Check if iptables is active and open port 1080 if needed
if iptables -L | grep -q "ACCEPT     tcp  --  anywhere             anywhere             tcp dpt:1080"; then
    echo "Port 1080 is already open in iptables."
else
    iptables -A INPUT -p tcp --dport 1080 -j ACCEPT
fi

# Restart dante-server
systemctl restart danted

# Enable dante-server to start at boot
systemctl enable danted
