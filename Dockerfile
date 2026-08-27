# Payload CMS (ecommerce-template-cms) — build context is the repo root
FROM node:20-alpine

RUN apk add --no-cache libc6-compat

WORKDIR /app

RUN npm install -g pnpm@9

# Install dependencies first for better layer caching
COPY ecommerce-template-cms/package.json ecommerce-template-cms/pnpm-lock.yaml ./
RUN pnpm install --frozen-lockfile

# Copy CMS source
COPY ecommerce-template-cms/ .

# Build Payload (Next.js) for production
RUN pnpm build

EXPOSE 3000

# Apply DB migrations (DATABASE_URI comes from runtime env), then start
CMD pnpm payload migrate && pnpm start
