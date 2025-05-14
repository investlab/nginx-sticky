#!/bin/bash
# Deploy:      Nginx reverse proxy with sticky mode
# Author:      ThaoPT - thaopt@nextsec.vn
# Last update: 25/9/2023

mkdir -p ./nginx/conf.d/ssl
mkdir -p ./nginx/log

touch ./nginx/conf.d/default.conf

cat > ./nginx/conf.d/demo.conf << EOL

# App cluster
upstream clusterapp {
        # round-robin is default setting
        #sticky;
        server 192.168.11.76:8081 max_fails=1  fail_timeout=3s;
        server 192.168.11.76:8082 max_fails=1  fail_timeout=3s;
        }



#HTTP redirect
server {
        listen  80;
        server_name sub.domain.com;
        return 301 https://sub.domain.com$request_uri;
       }


##### Enable for Root domain only - Chỉ dùng khi cấu hình doamin chính với WWW.domain.com
#server {
#	listen 443 ssl;

#	server_name www.domain.com;
	
#	# SSL
#	ssl_certificate /etc/nginx/ssl/www.doamin.com/www.domain.com.crt;
#	ssl_certificate_key /etc/nginx/ssl/www.doamin.com/www.doamin.com.pri.key;

#	return 301 https://doamin.com$request_uri;

#	include /etc/nginx/general.conf;
#}


server {
#       listen 443 ssl;  # khi enable dùng cert
		listen 8080;	 # khi khong dung cert;
        server_name     sub.domain.com;

        access_log      /var/log/nginx/sub.domain.com_access.log main;
        error_log       /var/log/nginx/sub.domain.com_error.log;

        sub_filter http://sub.domain.com https://sub.domain.com;
	sub_filter http://www.domain.com https://www.domain.com;
        sub_filter_once off;
        include /etc/nginx/general.conf;
        include /etc/nginx/conf.d/include/block-exploits.conf;


#    	ssl_certificate /etc/nginx/ssl/www.doamin.com/www.domain.com.crt;
#	ssl_certificate_key /etc/nginx/ssl/www.doamin.com/www.doamin.com.pri.key;

        #Reverse proxy
        location / {
             proxy_pass         http://clusterapp;
             include /etc/nginx/proxy.conf;
             }
	#Browser cache
	location ~*  \.(jpg|jpeg|png|gif|ico|css|js|pdf)$ {
             proxy_pass       http://10.0.0.8:8080;
             include /etc/nginx/proxy.conf;
             expires 30d;
        }

}


EOL

cat > ./nginx/conf.d/restrictdomain.conf << EOL
server {
    listen 80;
    server_name _;
    return       301 httpis://nextsec.vn;
}

EOL


cat > docker-compose.yml << EOL
version: '2'
  
services:
   nginx-sticky:
     container_name: nginx-sticky
     image: "wisoez/nginx-sticky:1.25.3-alpine"
     volumes:
       - "./nginx/conf.d:/etc/nginx/conf.d"
       - "./nginx/log:/var/log/nginx"
       - "./errors:/usr/share/nginx/errors"
       - "./nginx/nginx.conf:/etc/nginx/nginx.conf"
       - "./nginx/general.conf:/etc/nginx/general.conf"
       - "./nginx/proxy.conf:/etc/nginx/proxy.conf"
     restart: "always"
     ports:
       - "80:80"
       - "443:443"
EOL

docker-compose up -d
