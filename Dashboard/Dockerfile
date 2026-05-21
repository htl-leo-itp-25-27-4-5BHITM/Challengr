FROM node:20-alpine AS build

WORKDIR /app

COPY package*.json ./
RUN npm ci

COPY . .
RUN npm run build

FROM node:20-alpine

WORKDIR /app
ENV NODE_ENV=production
ENV PORT=4000

COPY --from=build /app/package*.json ./
RUN npm ci --omit=dev

COPY --from=build /app/dist/Dashboard ./dist/Dashboard

EXPOSE 4000

CMD ["node", "dist/Dashboard/server/server.mjs"]
