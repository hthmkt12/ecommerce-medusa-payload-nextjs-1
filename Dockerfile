# Next.js Storefront (ecommerce-template-storefront) — build context is the repo root
FROM node:20-alpine

RUN apk add --no-cache libc6-compat

WORKDIR /app

RUN npm install -g pnpm

# Install dependencies first for better layer caching
COPY ecommerce-template-storefront/package.json ecommerce-template-storefront/pnpm-lock.yaml ./
RUN pnpm install --no-frozen-lockfile

# Copy storefront source
COPY ecommerce-template-storefront/ .

# NEXT_PUBLIC_* vars are baked into the client bundle at build time.
# This branch deploys a fixed topology, so values are pinned here.
ENV NEXT_TELEMETRY_DISABLED=1 \
    NODE_ENV=production \
    MEDUSA_BACKEND_URL=https://hthmkt12-workspace-ecommerce.tose.sh \
    NEXT_PUBLIC_MEDUSA_PUBLISHABLE_KEY=pk_e8cc50ecd4b6af06e5a55e3c840d6aaa97a19d39db8382aee8fee4c1252059a3 \
    NEXT_PUBLIC_BASE_URL=https://hthmkt12-workspace-storefront.tose.sh \
    NEXT_PUBLIC_PAYLOAD_SERVER_URL=https://hthmkt12-workspace-ecommerce-cms.tose.sh \
    NEXT_PUBLIC_BACKEND_CONTAINER_NAME=hthmkt12-workspace-ecommerce.tose.sh

# Build for production (prerenders pages against the live Medusa backend)
RUN pnpm build

EXPOSE 8000

CMD ["pnpm", "start"]
