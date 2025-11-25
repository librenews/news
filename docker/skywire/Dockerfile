
ARG NODE_VERSION=20
FROM node:${NODE_VERSION}-bullseye AS base

ENV APP_HOME=/app/skywire \
    NODE_ENV=production

WORKDIR ${APP_HOME}
COPY skywire/package*.json ./
RUN npm install

FROM base AS dev
ENV NODE_ENV=development \
    PORT=6000 \
    HOST=0.0.0.0
COPY skywire ${APP_HOME}
CMD ["npm", "run", "dev"]

FROM base AS build
COPY skywire ${APP_HOME}
RUN npm run build || true

FROM node:${NODE_VERSION}-alpine AS production
ENV NODE_ENV=production \
    APP_HOME=/opt/skywire \
    PORT=6000 \
    HOST=0.0.0.0
WORKDIR ${APP_HOME}
COPY --from=build /app/skywire ./
RUN npm install --production
CMD ["node", "src/index.js"]

