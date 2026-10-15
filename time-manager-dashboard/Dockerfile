FROM node:22-alpine AS build

WORKDIR /app

COPY package.json package-lock.json ./
RUN npm ci

COPY . .
RUN npm run build

FROM build AS checks
RUN npm test

FROM nginx:1.28-alpine AS development

COPY --from=build /app/dist /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80

# Le même frontend compilé, avec une entrée TLS obligatoire pour le serveur.
FROM development AS production
COPY nginx.production.conf.template /etc/nginx/templates/default.conf.template
EXPOSE 443
