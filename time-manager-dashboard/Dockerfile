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

# La cible serveur utilise le même frontal HTTP que l'environnement local.
FROM development AS production
