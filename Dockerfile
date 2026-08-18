FROM caddy:2.10.2-alpine AS base

COPY server/Caddyfile /etc/caddy/Caddyfile
COPY index.html styles.css /srv/urge-surfer/public/
COPY src /srv/urge-surfer/public/src
COPY assets /srv/urge-surfer/public/assets

FROM base AS development

FROM base AS production
COPY config/production.js /srv/urge-surfer/public/src/features.js
