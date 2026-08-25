#!/bin/sh

# Run migrations and start server
echo "Running database migrations..."
npx medusa db:migrate

if [ "$SEED_ON_START" = "true" ]; then
  echo "Seeding database..."
  pnpm run seed || echo "WARNING: seeding failed, continuing without seed"
else
  echo "SEED_ON_START not enabled, skipping seed"
fi

if [ "$NODE_ENV" = "production" ]; then
  if [ ! -f .medusa/server/medusa-config.js ]; then
    echo "No prebuilt output found, building Medusa application..."
    pnpm run build
  fi
  echo "Starting Medusa server (production)..."
  pnpm run start
else
  echo "Starting Medusa development server..."
  pnpm run dev
fi
