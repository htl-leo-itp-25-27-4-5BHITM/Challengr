FROM node:20-alpine AS build

WORKDIR /app

COPY package*.json ./
RUN npm ci

COPY . .
RUN npm run build

# Create a production-only node_modules tree once, and reuse it in the runtime image.
RUN npm prune --omit=dev

FROM node:20-alpine

WORKDIR /app
ENV NODE_ENV=production
ENV PORT=4000

COPY --from=build /app/package*.json ./
COPY --from=build /app/node_modules ./node_modules

COPY --from=build /app/dist/Dashboard ./dist/Dashboard

EXPOSE 4000

CMD ["node", "dist/Dashboard/server/server.mjs"]
