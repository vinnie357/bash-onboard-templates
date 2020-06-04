#!/bin/bash
# logging
LOG_FILE=/var/log/startup-script.log
if [ ! -e $LOG_FILE ]
then
     touch $LOG_FILE
     exec &>>$LOG_FILE
else
    #if file exists, exit as only want to run once
    exit
fi

exec 1>$LOG_FILE 2>&1

## variables
repositories="${repositories}"
user="ubuntu"
#tool versions
terraformVersion="0.12.23"
terragruntVersion="0.23.4"
# install terraform locally
# jq 
# curl
# awscli
# f5 cli
# auto complete

# ubuntu 18.04
# terraform 12.23?
# awscli
# f5 cli
# terragrunt
#
# tests
# terraform -version
# inspec version
# terragrunt -version
# f5 --version
# aws --version
#
## vscode settings
## /repo/.vscode/extensions.json
# {
# 	// See https://go.microsoft.com/fwlink/?LinkId=827846 to learn about workspace recommendations.
# 	// Extension identifier format: $${publisher}.$${name}. Example: vscode.csharp
# 	// List of extensions which should be recommended for users of this workspace.
# 	"recommendations": [
# 		"mauve.terraform"
# 	],
# 	// List of extensions recommended by VS Code that should not be recommended for users of this workspace.
# 	"unwantedRecommendations": [		
# 	]
# }
#install-extensions:
#    cat extensions.txt | xargs -L 1 code --install-extension
## /home/ubuntu/.vscode-server/data/Machine/settings.json
# {
#     "files.eol": "\n",
#     "editor.tabSize": 4,
#     "editor.insertSpaces": true
# }
#
set -ex \
&& curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add - \
&& sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" \
&& sudo apt-get update -y \
&& sudo apt-get install -y apt-transport-https wget unzip jq git software-properties-common python3-pip ca-certificates gnupg-agent docker-ce docker-ce-cli containerd.io \
&& echo "docker" \
&& sudo usermod -aG docker $user \
&& sudo chown -R $user: /var/run/docker.sock \
&& echo "terraform" \
&& sudo wget https://releases.hashicorp.com/terraform/$terraformVersion/terraform_"$terraformVersion"_linux_amd64.zip \
&& sudo unzip ./terraform_"$terraformVersion"_linux_amd64.zip -d /usr/local/bin/ \
&& echo "awscli" \
&& sudo apt-get install awscli -y \
&& echo "f5 cli" \
&& pip3 install f5-cli \
&& echo "terragrunt" \
&& sudo wget https://github.com/gruntwork-io/terragrunt/releases/download/v"$terragruntVersion"/terragrunt_linux_amd64 \
&& sudo mv ./terragrunt_linux_amd64 /usr/local/bin/terragrunt \
&& sudo chmod +x /usr/local/bin/terragrunt \
&& echo "chef Inspec" \
&& curl https://omnitruck.chef.io/install.sh | sudo bash -s -- -P inspec \
&& echo "auto completion" \
&& complete -C '/usr/bin/aws_completer' aws \
&& terraform -install-autocomplete

echo "test tools"
echo '# test tools' >>/home/$user/.bashrc
echo '/bin/bash /testTools.sh' >>/home/$user/.bashrc
cat > /testTools.sh <<EOF 
#!/bin/bash
echo "=====Installed Versions====="
terraform -version
echo "inspec:"
inspec version
terragrunt -version
f5 --version
aws --version
echo "=====Installed Versions====="
EOF
echo "clone repositories"
cwd=$(pwd)
ifsDefault=$IFS
IFS=','
cd /home/$user
for repo in $repositories
do
    git clone $repo
    name=$(basename $repo )
    folder=$(basename $name .git)
    sudo chown -R $user $folder
done
IFS=$ifsDefault
echo "=====install coder====="
curl -sSOL https://github.com/cdr/code-server/releases/download/v3.4.1/code-server_3.4.1_amd64.deb
sudo dpkg -i code-server_3.4.1_amd64.deb
cat > /lib/systemd/system/code-server.service <<EOF
[Unit]
Description=code-server

[Service]
Type=simple
User=ubuntu
#Environment=PASSWORD=your_password
#ExecStart=/usr/bin/code-server --bind-addr 127.0.0.1:8080 --user-data-dir /var/lib/code-server --auth password
ExecStart=/usr/bin/code-server --bind-addr 127.0.0.1:8080 --auth none
Restart=always

[Install]
WantedBy=multi-user.target
EOF
sudo systemctl enable --now code-server
# install extensions for coder as user
wget $(curl -s https://api.github.com/repos/DumpySquare/vscode-f5-fast/releases | grep browser_download_url | grep '.vsix' | head -n 1 | cut -d '"' -f 4) 
sudo -u $user code-server --install-extension $(ls *vsix)
# exit user install
su root
rm *.vsix
systemctl restart code-server 
# Now visit http://127.0.0.1:8080. Your password is in ~/.config/code-server/config.yaml
cat > /coder.conf <<EOF
server {
    listen 80 default_server;
    server_name _;
    return 301 https://\$host\$request_uri;
}
map \$http_upgrade \$connection_upgrade {
        default upgrade;
        '' close;
    }
server {
    listen       443 ssl;
    server_name  localhost;
    ssl_certificate     /cert/server.crt; # The certificate file
    ssl_certificate_key /cert/server.key; # The private key file
    proxy_http_version 1.1;
    proxy_set_header Upgrade \$http_upgrade;
    proxy_set_header Connection \$connection_upgrade;
    proxy_set_header Host \$host;

    location / {
        proxy_pass http://127.0.0.1:8080;
    }

    error_page   500 502 503 504  /50x.html;
    location = /50x.html {
        root   /usr/share/nginx/html;
    }

}
EOF
echo "====self signed cert===="
mkdir -p /cert
cd /cert
openssl genrsa -des3 -passout pass:1234 -out server.pass.key 2048
openssl rsa -passin pass:1234 -in server.pass.key -out server.key
rm server.pass.key
openssl req -new -key server.key -out server.csr -subj "/C=US/ST=testville/L=testerton/O=Test testing/OU=Test Department/CN=test.example.com"
openssl x509 -req -sha256 -days 365 -in server.csr -signkey server.key -out server.crt
echo "=====start nginx====="
docker run --network="host" --restart always --name nginx-coder -v /coder.conf:/etc/nginx/conf.d/default.conf -v /cert:/cert -p 443:443 -p 80:80 -d nginx
echo "=====done====="
exit