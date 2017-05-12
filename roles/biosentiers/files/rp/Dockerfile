FROM nginx:1.13-alpine

LABEL maintainer "mei@heig-vd.ch"

ENV DUMB_INIT_VERSION="1.2.0"

# Copy app
RUN mkdir -p /var/www

# Add nginx configuration
ADD nginx.conf /etc/nginx/nginx.conf

# Add default SSL certificate
RUN mkdir -p /var/ssl/app
ADD server.key server.crt /var/ssl/app/

# Add init script
RUN apk add --update ca-certificates wget && \
    update-ca-certificates && \
    wget -O /usr/local/bin/dumb-init https://github.com/Yelp/dumb-init/releases/download/v${DUMB_INIT_VERSION}/dumb-init_${DUMB_INIT_VERSION}_amd64 && \
    chmod +x /usr/local/bin/dumb-init && \
    apk del ca-certificates wget

WORKDIR /var/www

ENTRYPOINT [ "/usr/local/bin/dumb-init", "--rewrite", "15:3", "--" ]

CMD [ "nginx" ]

EXPOSE 80
EXPOSE 443
