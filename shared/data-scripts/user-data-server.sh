#!/bin/bash

set -e

exec > >(sudo tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

ACL_DIRECTORY="/ops/shared/config"
NOMAD_BOOTSTRAP_TOKEN="/tmp/nomad_bootstrap"
NOMAD_USER_TOKEN="/tmp/nomad_user_token"
CONFIGDIR="/ops/shared/config"
NOMADVERSION=${nomad_version}
NOMADDOWNLOAD=https://releases.hashicorp.com/nomad/$${NOMADVERSION}/nomad_$${NOMADVERSION}_linux_amd64.zip
NOMADCONFIGDIR="/etc/nomad.d"
NOMADDIR="/opt/nomad"
HOME_DIR="ubuntu"
CLOUD_ENV=${cloud_env}


# gridscale special: download configs from s3
sudo mkdir -p $CONFIGDIR
sudo chmod 755 $CONFIGDIR
cd $CONFIGDIR
curl https://raw.githubusercontent.com/JanST123/nomad-gridscale/main/shared/config/nomad.hcl -O
curl https://raw.githubusercontent.com/JanST123/nomad-gridscale/main/shared/config/nomad.service -O
curl https://raw.githubusercontent.com/JanST123/nomad-gridscale/main/shared/config/consul.service -O
curl https://raw.githubusercontent.com/JanST123/nomad-gridscale/main/shared/config/consul.hcl -O
curl https://raw.githubusercontent.com/JanST123/nomad-gridscale/main/shared/config/server.hcl -O

# Install phase begin ---------------------------------------

# Install dependencies
case $CLOUD_ENV in
  gridscale)
    echo "CLOUD_ENV: gridscale"
    sudo apt-get update && sudo apt-get install -y software-properties-common
    IP_ADDRESS=${public_ip}
    PUBLIC_IP=${public_ip}
    ;;

  gce)
    echo "CLOUD_ENV: gce"
    sudo apt-get update && sudo apt-get install -y software-properties-common
    IP_ADDRESS=$(curl -H "Metadata-Flavor: Google" http://metadata/computeMetadata/v1/instance/network-interfaces/0/ip)
    ;;

  azure)
    echo "CLOUD_ENV: azure"
    sudo apt-get update && sudo apt-get install -y software-properties-common jq
    IP_ADDRESS=$(curl -s -H Metadata:true --noproxy "*" http://169.254.169.254/metadata/instance/network/interface/0/ipv4/ipAddress/0?api-version=2021-12-13 | jq -r '.["privateIpAddress"]')
    ;;

  *)
    exit "CLOUD_ENV not set to one of aws, gce, or azure - exiting."
    ;;
esac

sudo apt-get update
sudo apt-get install -y unzip tree redis-tools jq curl tmux
sudo apt-get clean


# Disable the firewall

sudo ufw disable || echo "ufw not installed"

# Download and install Nomad
curl -L $NOMADDOWNLOAD > nomad.zip

sudo unzip nomad.zip -d /usr/local/bin
sudo chmod 0755 /usr/local/bin/nomad
sudo chown root:root /usr/local/bin/nomad

sudo mkdir -p $NOMADCONFIGDIR
sudo chmod 755 $NOMADCONFIGDIR
sudo mkdir -p $NOMADDIR
sudo chmod 755 $NOMADDIR

# Docker
distro=$(lsb_release -si | tr '[:upper:]' '[:lower:]')
sudo apt-get install -y apt-transport-https ca-certificates gnupg2 
curl -fsSL https://download.docker.com/linux/debian/gpg | sudo apt-key add -
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/$${distro} $(lsb_release -cs) stable"
sudo apt-get update
sudo apt-get install -y docker-ce

# Java
#sudo add-apt-repository -y ppa:openjdk-r/ppa
#sudo apt-get update 
#sudo apt-get install -y openjdk-8-jdk
#JAVA_HOME=$(readlink -f /usr/bin/java | sed "s:bin/java::")

# Install phase finish ---------------------------------------

echo "Install complete"

# Server setup phase begin -----------------------------------
SERVER_COUNT=${server_count}

sed -i "s/SERVER_COUNT/$SERVER_COUNT/g" $CONFIGDIR/nomad.hcl
sed -i "s/RETRY_JOIN/$RETRY_JOIN/g" $CONFIGDIR/nomad.hcl
sed -i "s/IP_ADDRESS/$IP_ADDRESS/g" $CONFIGDIR/nomad.hcl
sudo cp $CONFIGDIR/nomad.hcl $NOMADCONFIGDIR
sudo cp $CONFIGDIR/nomad.service /etc/systemd/system/nomad.service

sudo systemctl enable nomad.service
sudo systemctl start nomad.service


export NOMAD_ADDR=http://$IP_ADDRESS:4646


# Add hostname to /etc/hosts

echo "127.0.0.1 $(hostname)" | sudo tee --append /etc/hosts

# Add Docker bridge network IP to /etc/resolv.conf (at the top)

echo "nameserver $DOCKER_BRIDGE_IP_ADDRESS" | sudo tee /etc/resolv.conf.new
cat /etc/resolv.conf | sudo tee --append /etc/resolv.conf.new
sudo mv /etc/resolv.conf.new /etc/resolv.conf

# Set env vars
echo "export NOMAD_ADDR=http://$IP_ADDRESS:4646" | sudo tee --append /home/$HOME_DIR/.bashrc
#echo "export JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64/jre"  | sudo tee --append /home/$HOME_DIR/.bashrc


# Server setup phase finish -----------------------------------

# install consul -----------------------------------
cd /root


export CONSUL_VERSION=${consul_version}
curl --silent --remote-name https://releases.hashicorp.com/consul/${CONSUL_VERSION}/consul_${CONSUL_VERSION}_linux_amd64.zip
unzip consul_${CONSUL_VERSION}_linux_amd64.zip
chown root:root consul
mv consul /usr/local/bin/
rm consul_${CONSUL_VERSION}_linux_amd64.zip

consul -autocomplete-install
complete -C /usr/local/bin/consul consul

useradd --system --home /etc/consul.d --shell /bin/false consul
mkdir --parents /opt/consul
chown --recursive consul:consul /opt/consul

mkdir --parents /etc/consul.d


# Prepare the TLS certificates for Consul
consul tls ca create
consul tls cert create -server -dc dc1
consul tls cert create -client -dc dc1

cp consul-agent-ca.pem /etc/consul.d/
cp dc1-server-consul-0* /etc/consul.d/

rm *.pem

# adapt the config
export CONSUL_KEY=`consul keygen`
echo $CONSUL_KEY

sed -i "s@CONSUL_KEY@$CONSUL_KEY@g" $CONFIGDIR/consul.hcl
sed -i "s/IP_ADDRESS/$IP_ADDRESS/g" $CONFIGDIR/consul.hcl
cp $CONFIGDIR/consul.hcl /etc/consul.d/
sed -i "s/SERVER_COUNT/$SERVER_COUNT/g" $CONFIGDIR/server.hcl
cp $CONFIGDIR/server.hcl /etc/consul.d/

chown --recursive consul:consul /etc/consul.d
chmod 640 /etc/consul.d/consul.hcl
chmod 640 /etc/consul.d/server.hcl
chmod 640 /etc/consul.d/dc1-server-consul-0-key.pem
chmod 640 /etc/consul.d/dc1-server-consul-0.pem
chmod 700 /etc/consul.d


# validate the config
consul validate /etc/consul.d/consul.hcl

# install and start the service
sudo cp $CONFIGDIR/consul.service /etc/systemd/system/consul.service
sudo systemctl enable consul.service
sudo systemctl start consul.service


# install consul finish -----------------------------------

# create directories for the persistant nomad volumes
mkdir -p /opt/nomad/host-volume1
mkdir -p /opt/nomad/host-volume-backup
mkdir -p /opt/nomad/host-volume-matomo