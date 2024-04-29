# SPDX-FileCopyrightText: 2023 XWiki CryptPad Team <contact@cryptpad.org> and contributors
#
# SPDX-License-Identifier: AGPL-3.0-or-later

# Multistage build to reduce image size and increase security
FROM node:lts-slim AS build

# Create folder for CryptPad
RUN mkdir /cryptpad
WORKDIR /cryptpad

# Copy CryptPad source code to the container
COPY . /cryptpad

RUN sed -i "s@//httpAddress: 'localhost'@httpAddress: '0.0.0.0'@" /cryptpad/config/config.example.js
RUN sed -i "s@installMethod: 'unspecified'@installMethod: 'docker'@" /cryptpad/config/config.example.js
  
# Install dependencies
RUN npm install --production \
    && npm run install:components

# Create actual CryptPad image
FROM node:lts-slim

LABEL maintainer="Michael Schmidt <schmidt.software@gmail.com>"

ENV DEBIAN_FRONTEND=noninteractive
RUN apt update && apt install -y git rdfind && rm -rf /var/lib/apt/lists/*

# Create user and group for CryptPad so it does not run as root
RUN groupadd cryptpad -g 4001
RUN useradd cryptpad -u 4001 -g 4001 -d /cryptpad

# Install wget for healthcheck
RUN apt-get update && apt-get install --no-install-recommends -y wget && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Copy cryptpad with installed modules
COPY --from=build --chown=cryptpad /cryptpad /cryptpad
USER cryptpad

# Copy docker-entrypoint.sh script
COPY --chown=cryptpad docker-entrypoint.sh /cryptpad/docker-entrypoint.sh

# Set workdir to cryptpad
WORKDIR /cryptpad

# Create directories
RUN mkdir blob block customize data datastore

# Volumes for data persistence
VOLUME /cryptpad/blob
VOLUME /cryptpad/block
VOLUME /cryptpad/customize
VOLUME /cryptpad/data
VOLUME /cryptpad/datastore

ENTRYPOINT ["/bin/bash", "/cryptpad/docker-entrypoint.sh"]

# Healthcheck
HEALTHCHECK --interval=1m CMD wget --no-verbose --tries=1 http://localhost:3000/ -q -O /dev/null || exit 1

# Ports
EXPOSE 3000 3001 3003

# Run cryptpad on startup
CMD ["npm", "start"]
