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
echo "==== starting ===="
apt-get update
apt-get install jq apt-transport-https ca-certificates -y
# make folders
mkdir /etc/ssl/nginx
cd /etc/ssl/nginx
# license
echo "==== secrets ===="
# access secret from secretsmanager
secrets=$(gcloud secrets versions access latest --secret="${secretName}")
# install cert key
echo "setting info from Metadata secret"
# cert
cat << EOF > /etc/ssl/nginx/nginx-repo.crt
$(echo $secrets | jq -r .cert)
EOF
# key
cat << EOF > /etc/ssl/nginx/nginx-repo.key
$(echo $secrets | jq -r .key)
EOF

echo "==== repos ===="
# add repo with signing key
wget https://nginx.org/keys/nginx_signing.key
apt-key add nginx_signing.key
apt-get install apt-transport-https lsb-release ca-certificates


printf "deb https://pkgs.nginx.com/instance-manager/debian stable nginx-plus\n" | tee /etc/apt/sources.list.d/instance-manager.list
wget -q -O /etc/apt/apt.conf.d/90pkgs-nginx https://cs.nginx.com/static/files/90pkgs-nginx

apt-get update

# install
echo "==== install ===="
apt-get install -y nginx-manager

function fileInstall {
# file download install
# download form remote source
# unzip
# install
apt-get -y install /home/user/nginx-manager-0.9.0-1_amd64.deb
}
# get localip
echo "=== get ip ==="
local_ipv4="$(curl http://169.254.169.254/latest/meta-data/local-ipv4)"
# config
echo "==== config ===="
mkdir -p /var/nginx-manager/
cat << EOF > /etc/nginx-manager/nginx-manager.conf
#
# /etc/nginx-manager/nginx-manager.conf
#

# Configuration file for NGINX Instance Manager Server

# bind address for all service ports (default "127.0.0.1")
bind-address: 127.0.0.1
# gRPC service port for agent communication (default "10000")
grpc-port: 10000
# gRPC-gateway service port for API and UI (default "11000")
gateway-port: 11000

# # path to x.509 certificate file (optional)
cert: /etc/ssl/nginx-manager/nginx-manager.crt
# # path to x.509 certificate key file (optional)
key: /etc/ssl/nginx-manager/nginx-manager.key

# set log level (panic, fatal, error, info, debug, trace; default: info) (default "info")
log:
    level: info
    path: /var/log/nginx-manager/
# Metrics default storage path (default "/tmp/metrics") (directory must be already present)
metrics:
    storage-path: /var/nginx-manager/
EOF

echo "==== license ===="
# license
cat << EOF > /etc/nginx-manager/nginx-manager.lic
$(echo $secrets | jq -r .license)
EOF
echo "==== certs ===="
path="/etc/ssl/nginx-manager"
mkdir -p $path
# self signed
echo "====self signed cert===="
openssl genrsa -aes256 -passout pass:1234 -out $${path}/server.pass.key 2048
openssl rsa -passin pass:1234 -in $${path}/server.pass.key -out $${path}/nginx-manager.key
openssl req -new -key $${path}/nginx-manager.key -out $${path}/server.csr -subj "/C=US/ST=testville/L=testerton/O=Test testing/OU=Test Department/CN=test.example.com"
openssl x509 -req -sha256 -days 365 -in $${path}/server.csr -signkey $${path}/nginx-manager.key -out $${path}/nginx-manager.crt
rm $${path}/server.pass.key
rm $${path}/server.csr
# from secrets
# # cert
# cat << EOF > /etc/ssl/nginx-manager/nginx-manager.crt
# $(echo $secrets | jq -r .webCert)
# EOF
# # key
# cat << EOF > /etc/ssl/nginx-manager/nginx-manager.key
# $(echo $secrets | jq -r .webKey)
# EOF


function selinux {
# selinux
sudo yum install -y nginx-manager-selinux

semanage port -a -t nginx-manager_port_t -p tcp 10001
semanage port -a -t nginx-manager_port_t -p tcp 11001
}
# start
echo "==== start service ===="
systemctl start nginx-manager

echo "==== done ===="
exit