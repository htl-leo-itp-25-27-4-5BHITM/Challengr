## Build static frontend with Vite and serve via nginx
## Use Node 20 (Vite requires >=20.19) - avoid alpine for better esbuild compatibility
FROM node:20-bullseye-slim AS build
WORKDIR /app

# install deps
COPY package.json package-lock.json* ./
RUN npm ci --silent || npm install --silent

# copy source and build
COPY . .
RUN npm run build

## Serve with nginx
FROM nginx:stable-alpine
COPY --from=build /app/dist /usr/share/nginx/html
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
