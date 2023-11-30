FROM nginx:1.25.3-alpine

LABEL maintainer="ThaoPT <thaopt@nextsec.vn>"

RUN apk add --update alpine-sdk pcre-dev pcre

RUN apk add --no-cache --virtual .build-deps \
        gcc \
        libc-dev \
        make \
        openssl-dev \
        pcre-dev \
        pcre  \
	zlib-dev \
        linux-headers \
        curl \
        gnupg \
        libxslt-dev \
        gd-dev \
        perl-dev \
    && apk add --no-cache --virtual .libmodsecurity-deps \
        pcre-dev \
        libxml2-dev \
        git \
        libtool \
        automake \
        autoconf \
        g++ \
        flex \
        bison \
        yajl-dev \
		patch \
        make \
    # Add runtime dependencies that should not be removed
    && apk add --no-cache \
        doxygen \
        geoip \
        geoip-dev \
        yajl \
        libstdc++ \
        git \
        sed \
        libmaxminddb-dev


WORKDIR /opt

RUN echo 'Installing Nginx connector' && \
    wget http://nginx.org/download/nginx-$NGINX_VERSION.tar.gz && \
    tar zxvf nginx-$NGINX_VERSION.tar.gz

# https://bitbucket.org/nginx-goodies/nginx-sticky-module-ng/issues/33/cannot-compile-with-nginx-1134-and-module
RUN echo 'Installing Sticky - Nginx session' && \
    git clone https://github.com/xu2ge/nginx-sticky-module-ng.git
    # real: git clone https://bitbucket.org/nginx-goodies/nginx-sticky-module-ng.git
    # clone with update and fix in pull request :git clone https://github.com/Refinitiv/nginx-sticky-module-ng.git
   
WORKDIR /opt/GeoIP

RUN git clone -b master --single-branch https://github.com/leev/ngx_http_geoip2_module.git .

WORKDIR /opt/nginx-$NGINX_VERSION

RUN ./configure --with-compat --add-dynamic-module=../GeoIP && \
    make modules && \
    cp objs/ngx_http_geoip2_module.so /etc/nginx/modules

RUN ./configure --prefix=/etc/nginx --sbin-path=/usr/sbin/nginx --modules-path=/usr/lib/nginx/modules --conf-path=/etc/nginx/nginx.conf --error-log-path=/var/log/nginx/error.log --http-log-path=/var/log/nginx/access.log --pid-path=/var/run/nginx.pid --lock-path=/var/run/nginx.lock --http-client-body-temp-path=/var/cache/nginx/client_temp --http-proxy-temp-path=/var/cache/nginx/proxy_temp --http-fastcgi-temp-path=/var/cache/nginx/fastcgi_temp --http-uwsgi-temp-path=/var/cache/nginx/uwsgi_temp --http-scgi-temp-path=/var/cache/nginx/scgi_temp --user=nginx --group=nginx --with-compat --with-file-aio --with-threads --with-http_addition_module --with-http_auth_request_module --with-http_dav_module --with-http_flv_module --with-http_gunzip_module --with-http_gzip_static_module --with-http_mp4_module --with-http_random_index_module --with-http_realip_module --with-http_secure_link_module --with-http_slice_module --with-http_ssl_module --with-http_stub_status_module --with-http_sub_module --with-http_v2_module --with-mail --with-mail_ssl_module --with-stream --with-stream_realip_module --with-stream_ssl_module --with-stream_ssl_preread_module --with-cc-opt='-g -O2 -fstack-protector --param=ssp-buffer-size=4 -Wformat -Werror=format-security -Wp,-D_FORTIFY_SOURCE=2 -fPIC' --with-ld-opt='-Wl,-Bsymbolic-functions -Wl,-z,relro -Wl,-z,now -Wl,--as-needed -pie'  --add-module=../nginx-sticky-module-ng && \
    make  && \
    make install


WORKDIR /opt


RUN rm -fr /etc/nginx/conf.d/ && \
    rm -fr /etc/nginx/nginx.conf

COPY conf/nginx/ /etc/nginx/
COPY errors /usr/share/nginx/errors
ADD  ./conf/nginx/general.conf	/etc/nginx/
ADD  ./conf/nginx/proxy.conf	/etc/nginx/

# Edit link de download
# https://download.maxmind.com/app/geoip_download?edition_id=GeoLite2-City&license_key=YOUR_LICENSE_KEY&suffix=tar.gz
# https://download.maxmind.com/app/geoip_download?edition_id=GeoLite2-Country&license_key=YOUR_LICENSE_KEY&suffix=tar.gz
# https://forum.matomo.org/t/maxmind-is-changing-access-to-free-geolite2-databases/35439/3

COPY ./GeoLite2-City.tar.gz /tmp/
COPY ./GeoLite2-Country.tar.gz /tmp/
RUN mkdir -p /etc/nginx/geoip && \
    tar -xvzf /tmp/GeoLite2-City.tar.gz --strip-components=1 && \
    tar -xvzf /tmp/GeoLite2-Country.tar.gz --strip-components=1 && \
    mv *.mmdb /etc/nginx/geoip/

RUN chown -R nginx:nginx /usr/share/nginx /etc/nginx

#delete uneeded and clean up
RUN apk del .build-deps && \
    apk del .libmodsecurity-deps && \
    rm -fr /tmp/GeoLite2* && \
    rm -fr GeoIp && \
    rm -fr nginx-$NGINX_VERSION.tar.gz && \
    rm -fr nginx-$NGINX_VERSION && \
    rm -fr nginx-sticky-module-ng  && \
    touch /opt/stickey.txt  && \
    rm -rf /opt/*.gz

WORKDIR /usr/share/nginx/html

