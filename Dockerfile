# Payload CMS (ecommerce-template-cms) — build context is the repo root
FROM node:20-alpine

RUN apk add --no-cache libc6-compat

WORKDIR /app

RUN npm install -g pnpm

# Install dependencies first for better layer caching
COPY ecommerce-template-cms/package.json ecommerce-template-cms/pnpm-lock.yaml ./
RUN pnpm install --frozen-lockfile

# Copy CMS source
COPY ecommerce-template-cms/ .

EXPOSE 3000

# Start Payload (Next.js) in development mode
CMD ["pnpm", "dev"]
