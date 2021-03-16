# NIM startup
# logging
LOG_FILE="/var/log/startup.log"
if [ ! -e $LOG_FILE ]
then
     touch $LOG_FILE
     exec &>>$LOG_FILE
else
    #if file exists, exit as only want to run once
    exit
fi
exec 1>$LOG_FILE 2>&1
echo "starting"
apt-get update
apt-get install jq apt-transport-https ca-certificates -y
# make folders
mkdir /etc/ssl/nginx
cd /etc/ssl/nginx
# license
# access secret from secretsmanager
secrets=$(gcloud secrets versions access latest --secret="${secretName}")
# install cert key
echo "setting info from Metadata secret"
# cert
cat << EOF > /etc/ssl/nginx/nginx-manager-repo.crt
$(echo $secrets | jq -r .cert)
EOF
# key
cat << EOF > /etc/ssl/nginx/nginx-manager-repo.key
$(echo $secrets | jq -r .key)
EOF
# add repo with signing key
wget https://nginx.org/keys/nginx_signing.key
apt-key add nginx_signing.key
apt-get install apt-transport-https lsb-release ca-certificates

printf "deb https://pkgs.nginx.com/instance-manager/debian stable nginx-plus\n" | sudo /etc/apt/sources.list.d/instance-manager.list
wget -q -O /etc/apt/apt.conf.d/90pkgs-nginx https://cs.nginx.com/static/files/90pkgs-nginx
apt-get update

# install
sudo apt-get install -y nginx-manager

function fileInstall {
# file download install
# download form remote source
# unzip
# install
apt-get -y install /home/user/nginx-manager-0.9.0-1_amd64.deb
}

# config
cat > /etc/nginx-manager/nginx-manager.conf <<EOF 
#
# /etc/nginx-manager/nginx-manager.conf
#

# Configuration file for NGINX Instance Manager Server

# bind address for all service ports (default "127.0.0.1")
bind-address: 10.1.1.4
# gRPC service port for agent communication (default "10000")
grpc-port: 10000
# gRPC-gateway service port for API and UI (default "11000")
gateway-port: 11000

# # path to x.509 certificate file (optional)
# cert:
# # path to x.509 certificate key file (optional)
# key:

# set log level (panic, fatal, error, info, debug, trace; default: info) (default "info")
log:
    level: info
    path: /var/log/nginx-manager/
# Metrics default storage path (default "/tmp/metrics") (directory must be already present)
metrics:
    storage-path: /var/nginx-manager/
EOF

function selinux {
# selinux
sudo yum install -y nginx-manager-selinux

semanage port -a -t nginx-manager_port_t -p tcp 10001
semanage port -a -t nginx-manager_port_t -p tcp 11001
}
# start
systemctl start nginx-manager