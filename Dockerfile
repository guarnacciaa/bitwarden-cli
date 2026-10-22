# Bitwarden CLI + a small serve wrapper, published daily by CI when npm has a
# new @bitwarden/cli release. Base: the official node image. No third-party image
# in the chain.
FROM node:22-alpine

# CI passes the exact version it resolved; a local `docker build` gets `latest`.
ARG CLI_VERSION=latest
RUN npm install -g "@bitwarden/cli@${CLI_VERSION}" && npm cache clean --force

COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

ENV HOME=/data
WORKDIR /data
EXPOSE 8091
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
