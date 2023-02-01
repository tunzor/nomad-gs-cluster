#!/bin/bash

set -e

exec > >(sudo tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

ACL_DIRECTORY="/ops/shared/config"
CONSUL_BOOTSTRAP_TOKEN="/tmp/consul_bootstrap"
NOMAD_BOOTSTRAP_TOKEN="/tmp/nomad_bootstrap"
NOMAD_USER_TOKEN="/tmp/nomad_user_token"
CONFIGDIR="/ops/shared/config"
NOMADVERSION=1.4.3
NOMADDOWNLOAD=https://releases.hashicorp.com/nomad/$${NOMADVERSION}/nomad_$${NOMADVERSION}_linux_amd64.zip
NOMADCONFIGDIR="/etc/nomad.d"
NOMADDIR="/opt/nomad"
HOME_DIR="ubuntu"
CLOUD_ENV=${cloud_env}

# Install phase begin ---------------------------------------

# Install dependencies
case $CLOUD_ENV in
  aws)
    echo "CLOUD_ENV: aws"
    IP_ADDRESS=$(curl http://instance-data/latest/meta-data/local-ipv4)
    PUBLIC_IP=$(curl http://instance-data/latest/meta-data/public-ipv4)
    sudo apt-get install -y software-properties-common
    ;;

  gce)
    echo "CLOUD_ENV: gce"
    IP_ADDRESS=$(curl -H "Metadata-Flavor: Google" http://metadata/computeMetadata/v1/instance/network-interfaces/0/ip)
    sudo apt-get update && sudo apt-get install -y software-properties-common
    ;;

  azure)
    echo "CLOUD_ENV: azure"
    IP_ADDRESS=$(curl -s -H Metadata:true --noproxy "*" http://169.254.169.254/metadata/instance/network/interface/0/ipv4/ipAddress/0?api-version=2021-12-13 | jq -r '.["privateIpAddress"]')
    sudo apt-get install -y software-properties-common
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
sudo add-apt-repository -y ppa:openjdk-r/ppa
sudo apt-get update 
sudo apt-get install -y openjdk-8-jdk
JAVA_HOME=$(readlink -f /usr/bin/java | sed "s:bin/java::")

# Install phase finish ---------------------------------------

echo "Install complete"

# Server setup phase begin -----------------------------------
SERVER_COUNT=${server_count}
RETRY_JOIN="${retry_join}"
NOMAD_BINARY=${nomad_binary}


# Nomad

## Replace existing Nomad binary if remote file exists
if [[ `wget -S --spider $NOMAD_BINARY  2>&1 | grep 'HTTP/1.1 200 OK'` ]]; then
  curl -L $NOMAD_BINARY > nomad.zip
  sudo unzip -o nomad.zip -d /usr/local/bin
  sudo chmod 0755 /usr/local/bin/nomad
  sudo chown root:root /usr/local/bin/nomad
fi

sed -i "s/SERVER_COUNT/$SERVER_COUNT/g" $CONFIGDIR/nomad.hcl
sed -i "s/RETRY_JOIN/$RETRY_JOIN/g" $CONFIGDIR/nomad.hcl
sed -i "s/PUBLIC_IP/$PUBLIC_IP/g" $CONFIGDIR/nomad.hcl
sudo cp $CONFIGDIR/nomad.hcl $NOMADCONFIGDIR
sudo cp $CONFIGDIR/nomad.service /etc/systemd/system/nomad.service

sudo systemctl enable nomad.service
sudo systemctl start nomad.service
sleep 10
export NOMAD_ADDR=http://$IP_ADDRESS:4646

# Add hostname to /etc/hosts

echo "127.0.0.1 $(hostname)" | sudo tee --append /etc/hosts

# Add Docker bridge network IP to /etc/resolv.conf (at the top)

echo "nameserver $DOCKER_BRIDGE_IP_ADDRESS" | sudo tee /etc/resolv.conf.new
cat /etc/resolv.conf | sudo tee --append /etc/resolv.conf.new
sudo mv /etc/resolv.conf.new /etc/resolv.conf

# Set env vars
echo "export NOMAD_ADDR=http://$IP_ADDRESS:4646" | sudo tee --append /home/$HOME_DIR/.bashrc
echo "export JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64/jre"  | sudo tee --append /home/$HOME_DIR/.bashrc

# Server setup phase finish -----------------------------------

# sed -i "s/CONSUL_TOKEN/${nomad_consul_token_secret}/g" /etc/nomad.d/nomad.hcl

# sudo systemctl restart nomad

# Wait for nomad servers to come up and bootstrap nomad ACL
for i in {1..12}; do
    # capture stdout and stderr
    set +e
    sleep 5
    OUTPUT=$(nomad acl bootstrap /tmp/consul_bootstrap 2>&1)
    if [ $? -ne 0 ]; then
        echo "nomad acl bootstrap: $OUTPUT"
        if [[ "$OUTPUT" = *"No cluster leader"* ]]; then
            echo "nomad no cluster leader"
            continue
        else
            echo "nomad already bootstrapped"
            exit 0
        fi
    fi
    set -e

    echo "$OUTPUT" | grep -i secret | awk -F '=' '{print $2}' | xargs | awk 'NF' > $NOMAD_BOOTSTRAP_TOKEN
    if [ -s $NOMAD_BOOTSTRAP_TOKEN ]; then
        echo "nomad bootstrapped"
        break
    fi
done

nomad acl policy apply -token "$(cat $NOMAD_BOOTSTRAP_TOKEN)" -description "Policy to allow reading of agents and nodes and listing and submitting jobs in all namespaces." node-read-job-submit $ACL_DIRECTORY/nomad-acl-user.hcl

nomad acl token create -token "$(cat $NOMAD_BOOTSTRAP_TOKEN)" -name "read-token" -policy node-read-job-submit | grep -i secret | awk -F "=" '{print $2}' | xargs > $NOMAD_USER_TOKEN

# Write user token to kv
# consul kv put -token-file=$CONSUL_BOOTSTRAP_TOKEN nomad_user_token "$(cat $NOMAD_USER_TOKEN)"

echo "ACL bootstrap end"

# #!/bin/bash

# set -e

# exec > >(sudo tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

# sudo bash /ops/shared/scripts/setup.sh "${cloud_env}"
# sudo bash /ops/shared/scripts/server.sh "${cloud_env}" "${server_count}" '${retry_join}' "${nomad_binary}"

# ACL_DIRECTORY="/ops/shared/config"
# CONSUL_BOOTSTRAP_TOKEN="/tmp/consul_bootstrap"
# NOMAD_BOOTSTRAP_TOKEN="/tmp/nomad_bootstrap"
# NOMAD_USER_TOKEN="/tmp/nomad_user_token"

# sed -i "s/CONSUL_TOKEN/${nomad_consul_token_secret}/g" /etc/nomad.d/nomad.hcl

# sudo systemctl restart nomad

# echo "Finished server setup"

# echo "ACL bootstrap begin"

# # Wait until leader has been elected and bootstrap consul ACLs
# for i in {1..9}; do
#     # capture stdout and stderr
#     set +e
#     sleep 5
#     OUTPUT=$(consul acl bootstrap 2>&1)
#     if [ $? -ne 0 ]; then
#         echo "consul acl bootstrap: $OUTPUT"
#         if [[ "$OUTPUT" = *"No cluster leader"* ]]; then
#             echo "consul no cluster leader"
#             continue
#         else
#             echo "consul already bootstrapped"
#             exit 0
#         fi

#     fi
#     set -e

#     echo "$OUTPUT" | grep -i secretid | awk '{print $2}' > $CONSUL_BOOTSTRAP_TOKEN
#     if [ -s $CONSUL_BOOTSTRAP_TOKEN ]; then
#         echo "consul bootstrapped"
#         break
#     fi
# done


# consul acl policy create -name 'nomad-auto-join' -rules="@$ACL_DIRECTORY/consul-acl-nomad-auto-join.hcl" -token-file=$CONSUL_BOOTSTRAP_TOKEN

# consul acl role create -name "nomad-auto-join" -description "Role with policies necessary for nomad servers and clients to auto-join via Consul." -policy-name "nomad-auto-join" -token-file=$CONSUL_BOOTSTRAP_TOKEN

# consul acl token create -accessor=${nomad_consul_token_id} -secret=${nomad_consul_token_secret} -description "Nomad server/client auto-join token" -role-name nomad-auto-join -token-file=$CONSUL_BOOTSTRAP_TOKEN

# # Wait for nomad servers to come up and bootstrap nomad ACL
# for i in {1..12}; do
#     # capture stdout and stderr
#     set +e
#     sleep 5
#     OUTPUT=$(nomad acl bootstrap 2>&1)
#     if [ $? -ne 0 ]; then
#         echo "nomad acl bootstrap: $OUTPUT"
#         if [[ "$OUTPUT" = *"No cluster leader"* ]]; then
#             echo "nomad no cluster leader"
#             continue
#         else
#             echo "nomad already bootstrapped"
#             exit 0
#         fi
#     fi
#     set -e

#     echo "$OUTPUT" | grep -i secret | awk -F '=' '{print $2}' | xargs | awk 'NF' > $NOMAD_BOOTSTRAP_TOKEN
#     if [ -s $NOMAD_BOOTSTRAP_TOKEN ]; then
#         echo "nomad bootstrapped"
#         break
#     fi
# done

# nomad acl policy apply -token "$(cat $NOMAD_BOOTSTRAP_TOKEN)" -description "Policy to allow reading of agents and nodes and listing and submitting jobs in all namespaces." node-read-job-submit $ACL_DIRECTORY/nomad-acl-user.hcl

# nomad acl token create -token "$(cat $NOMAD_BOOTSTRAP_TOKEN)" -name "read-token" -policy node-read-job-submit | grep -i secret | awk -F "=" '{print $2}' | xargs > $NOMAD_USER_TOKEN

# # Write user token to kv
# consul kv put -token-file=$CONSUL_BOOTSTRAP_TOKEN nomad_user_token "$(cat $NOMAD_USER_TOKEN)"

# echo "ACL bootstrap end"
