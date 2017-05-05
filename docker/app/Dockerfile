FROM node:6.10.3-alpine

LABEL maintainer "mei@heig-vd.ch"

ENV NODE_ENV="production" \
    PORT="3000" \
    S6_OVERLAY_VERSION="1.19.1.1"

# Install s6 overlay for service supervision (https://github.com/just-containers/s6-overlay)
RUN apk add --update --virtual .build-deps curl \
    && curl -sSLo /tmp/s6.tar.gz https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-amd64.tar.gz \
    && tar xzf /tmp/s6.tar.gz -C / \
    && rm -f /tmp/s6.tar.gz \
    && apk del .build-deps \
    && rm -rf /var/cache/apk/*

# Set up s6 configuration files
ADD etc /etc/

# Install postgresql client (to test database connection on container startup)
RUN apk add --update postgresql-client \
    && rm -rf /var/cache/apk/*

# Install backend dependencies
RUN mkdir -p /usr/src/app/public
WORKDIR /usr/src/app
ADD backend/package.json /usr/src/app/
RUN npm install && npm cache clean

# Copy backend
ADD backend /usr/src/app/

# Copy frontend
#RUN mkdir -p /tmp/app /var/www/app
#ADD . /tmp/app/
#WORKDIR /tmp/app
# Docker bug: node-sass required because of https://github.com/sass/node-sass/issues/983
#RUN npm install node-sass && \
#    npm install && \
#    npm cache clean && \
#    npm run build && \
#    cp -R /tmp/app/dist/* /var/www/app && \
#    rm -fr /tmp/*
ADD frontend/dist /usr/src/app/public/

# Set s6 as the entrypoint
ENTRYPOINT [ "/init" ]

EXPOSE 3000
