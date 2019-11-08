# Node version to use for root images
ARG NODE_VERSION=8

# Stage 1: Create the build image
FROM node:${NODE_VERSION} AS build
ENV NODE_ENV=production
WORKDIR /build
RUN yarn add node-gyp --global


# Stage 2: Build Gekko dependencies
# Using npm in this stage because yarn stops with errors while building talib/tulind
FROM build AS gekko
COPY package.json .
RUN npm install \
    && npm install \
      redis@0.10.0 \
      talib@1.0.2 \
      tulind@0.8.7 \
      mongojs@2.4.0 \
      pg


# Stage 3: Build Gekko Broker dependencies
FROM build AS broker
COPY exchange/package.json .
RUN yarn install


# Stage 4: Build the final application image
FROM node:${NODE_VERSION}-slim
ENV HOST=localhost \
    PORT=3000 \
    NODE_ENV=production
WORKDIR /app
COPY . /app
COPY --from=gekko /build/ /app/
COPY --from=broker /build/ /app/exchange/
RUN mv /app/docker-entrypoint.sh /entrypoint.sh \
    && chmod +x /entrypoint.sh \
    && alias gekko="node /app/gekko"
ENTRYPOINT ["/entrypoint.sh"]
VOLUME ["/app/history", "/app/strategies", "/app/config"]
EXPOSE ${PORT}
CMD ["--config", "config.js", "--ui"]
