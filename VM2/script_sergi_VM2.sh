#!/bin/bash

#Actualización de repositorios
apt install net-tools
apt-get update

#Configurar disco
mkdir /var/lib/elasticsearch
mkfs.ext4 /dev/sdb
mount /dev/sdb /var/lib/elasticsearch
rm -r /var/lib/elasticsearch/*

LINE_TO_ADD="/dev/sdb          /var/lib/elasticsearch               ext4               defaults             0 2"
echo "$LINE_TO_ADD" | sudo tee -a /etc/fstab > /dev/null

#Instalación de dependencias Elastic.co
wget -qO - https://artifacts.elastic.co/GPG-KEY-elasticsearch | sudo apt-key add -
sudo apt-get install apt-transport-https
echo "deb https://artifacts.elastic.co/packages/8.x/apt stable main" | sudo tee -a /etc/apt/sources.list.d/elastic-8.x.list
sudo apt-get update

#Instalación de Elasticsearch
wget -qO - https://artifacts.elastic.co/GPG-KEY-elasticsearch | sudo gpg --dearmor -o /usr/share/keyrings/elasticsearch-keyring.gpg
sudo apt-get install apt-transport-https
echo "deb [signed-by=/usr/share/keyrings/elasticsearch-keyring.gpg] https://artifacts.elastic.co/packages/8.x/apt stable main" | sudo tee /etc/apt/sources.list.d/elastic-8.x.list
apt-get update && sudo apt-get install elasticsearch
sudo sed -i '$a\action.auto_create_index: "*"' /etc/elasticsearch/elasticsearch.yml

#Configurar permisos
sudo chown -R elasticsearch:elasticsearch /var/lib/elasticsearch
sudo chmod -R 755 /var/lib/elasticsearch

#Configurar Elastic  - Aqui el error!!!!!!!!!!!
sudo sed -i 's/^#network.host: .*/network.host: 0.0.0.0/g' /etc/elasticsearch/elasticsearch.yml
#sudo sed -i 's/^#cluster.name: .*/cluster.name: wordpress-cluster/g' /etc/elasticsearch/elasticsearch.yml
#sudo sed -i 's/^#node.name: /node.name: /g' /etc/elasticsearch/elasticsearch.yml

#Iniciar
systemctl enable elasticsearch --now
sudo systemctl daemon-reload

#Generaremos 2 contraseñas
export admin=$(/usr/share/elasticsearch/bin/elasticsearch-reset-password -u elastic -b -s)
export config=$(/usr/share/elasticsearch/bin/elasticsearch-reset-password -u kibana_system -b -s)

echo "$admin" > admin.txt
echo "$config" > config.txt


#Instalación de Kibana
apt install kibana
mkdir /etc/kibana/certs
cp /etc/elasticsearch/certs/http_ca.crt /etc/kibana/certs/http_ca.crt

#Configuración kibana
sed -i 's/#server.port: 5601/server.port: 5601/g' /etc/kibana/kibana.yml
sed -i 's/^#server.host: "localhost"/server.host: "0.0.0.0"/' /etc/kibana/kibana.yml
#sed -i 's/#elasticsearch.hosts/elasticsearch.hosts/g' /etc/kibana/kibana.yml
sed -i 's|#elasticsearch.hosts: \["http://localhost:9200"\]|elasticsearch.hosts: \["https://localhost:9200"\]|' /etc/kibana/kibana.yml
sed -i 's/#elasticsearch.username/elasticsearch.username/g' /etc/kibana/kibana.yml
sed -i "s/#elasticsearch.password: \"pass\"/elasticsearch.password: \"$config\"/g" /etc/kibana/kibana.yml
sed -i 's|#elasticsearch.ssl.certificateAuthorities: \[ "/path/to/your/CA.pem" \]|elasticsearch.ssl.certificateAuthorities: \[ "/etc/kibana/certs/http_ca.crt" \]|g' /etc/kibana/kibana.yml

#Instalación de Logstash
apt install logstash
mkdir /etc/logstash/certs
sudo chown -R logstash:logstash /etc/logstash/certs
apt install curl -y

#Configuración permisos
cp /etc/elasticsearch/certs/http_ca.crt /etc/logstash/certs/http_ca.crt
sudo chown :logstash /etc/logstash/certs/http_ca.crt
sudo chmod 640 /etc/logstash/certs/http_ca.crt

#Crear rol logstash
curl -XPOST --cacert /etc/logstash/certs/http_ca.crt -u elastic:$admin 'https://localhost:9200/_security/role/logstash_write_role' -H "Content-Type: application/json" -d '{
  "cluster": [
    "monitor",
    "manage_index_templates"
  ],
  "indices": [
    {
      "names": [
        "*"
      ],
      "privileges": [
        "write",
        "create_index",
        "auto_configure"
      ],
      "field_security": {
        "grant": [
          "*"
        ]
      }
    }
  ],
  "run_as": [],
  "metadata": {},
  "transient_metadata": {
    "enabled": true
  }
}'


#Crear el usuario de logstash
curl -XPOST --cacert /etc/logstash/certs/http_ca.crt -u elastic:$admin 'https://localhost:9200/_security/user/logstash' -H "Content-Type: application/json" -d '{
  "password" : "keepcoding_logstash",
  "roles" : ["logstash_admin", "logstash_system", "logstash_write_role"],
  "full_name" : "Logstash User"
}'


#Configuración de los inputs y outputs
touch /etc/logstash/conf.d/02-beats-input.conf


cat <<_EOT_ > /etc/logstash/conf.d/02-beats-input.conf
input {
  beats {
    port => 5044
  }
}
_EOT_


touch /etc/logstash/conf.d/30-elasticsearch-output.conf


cat <<_EOT_ > /etc/logstash/conf.d/30-elasticsearch-output.conf
output {
  elasticsearch {
    hosts => ["https://localhost:9200"]
    manage_template => false
    index => "filebeat-demo-%{+YYYY.MM.dd}"
    user => "logstash"
    password => "keepcoding_logstash"
    cacert => "/etc/logstash/certs/http_ca.crt"
  }
}
_EOT_

#Iniciar
systemctl enable logstash --now
systemctl restart elasticsearch
systemctl enable kibana --now

admin=$(cat admin.txt)
config=$(cat config.txt)

echo "¡El script se ejecutó correctamente!"

