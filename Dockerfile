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

# Build once at image build time so containers boot straight into `medusa start`.
# NOTE: NODE_ENV must NOT be production here — medusa-config.ts refuses to boot
# production without secrets, which are only injected at runtime.
# Admin dashboard is skipped unless explicitly enabled via --build-arg.
ARG DISABLE_ADMIN=true
ENV DISABLE_ADMIN=${DISABLE_ADMIN}
RUN pnpm run build

EXPOSE 9000

RUN chmod +x start.sh

CMD ./start.sh
