# Medusa backend (ecommerce-template) — build context is the repo root
FROM node:20-alpine

# libc6-compat needed by some native deps
RUN apk add --no-cache libc6-compat

WORKDIR /app

RUN npm install -g pnpm

# Install dependencies first for better layer caching
COPY ecommerce-template/package.json ecommerce-template/pnpm-lock.yaml ./
RUN pnpm install --frozen-lockfile

# Copy backend source
COPY ecommerce-template/ .

EXPOSE 9000

RUN chmod +x start.sh

CMD ./start.sh
