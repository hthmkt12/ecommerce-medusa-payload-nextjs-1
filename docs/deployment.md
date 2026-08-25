# Deployment

## Platform: TOSE.sh (workspace `hthmkt12-workspace`)

Fork used for deploys: `hthmkt12/ecommerce-medusa-payload-nextjs-1`
(upstream `DrunkOldDog/ecommerce-medusa-payload-nextjs` is read-only for this account).

Each service = one TOSE project, one branch, one root-level Dockerfile on that branch.

| Service | TOSE project | Branch | URL | Port |
|---|---|---|---|---|
| Medusa backend | `ecommerce` | `hthmkt12/filefish` | https://hthmkt12-workspace-ecommerce.tose.sh | 9000 |
| Payload CMS | `ecommerce-cms` | `deploy/cms` | https://hthmkt12-workspace-ecommerce-cms.tose.sh | 3000 |
| Next.js storefront | `ecommerce-storefront` | `deploy/storefront` | https://hthmkt12-workspace-storefront.tose.sh | 8000 |

## Deploy Command

```bash
# backend
tose deploy --project ecommerce

# cms
tose deploy --project ecommerce-cms

# storefront
tose deploy --project ecommerce-storefront
```

Auto-deploy is enabled per branch (push to the branch triggers a rebuild).

Rollback: TOSE dashboard → project → Deployments → pick previous deployment.

## Database

Single Supabase Postgres instance (ap-northeast-2, session pooler), two databases:

- `postgres` → Medusa (migrations run by container `start.sh`)
- `payload` → Payload CMS (migrations in repo: `src/migrations/`, applied via `pnpm payload migrate` at container start)

Note: TOSE managed DB provisioning was broken at deploy time (see Known Issues), hence Supabase.

## Environment Variables (per TOSE project)

### ecommerce (backend)
- `DATABASE_URL`, `JWT_SECRET`, `COOKIE_SECRET`, `NODE_ENV`
- `STORE_CORS`, `ADMIN_CORS`, `AUTH_CORS` (include the tose.sh domains)
- `PAYLOAD_SERVER_URL=https://hthmkt12-workspace-ecommerce-cms.tose.sh`
- `PAYLOAD_API_KEY=<payload users API key>` — rotate after rotating the key in CMS admin
- `PAYLOAD_USER_COLLECTION=users`
- `DISABLE_ADMIN=true` — required on 0.5 CPU; remove and bump resources to enable `/app`

### ecommerce-cms
- `DATABASE_URI` (Supabase `payload` db), `PAYLOAD_SECRET`, `NODE_ENV=production`

### ecommerce-storefront
- `MEDUSA_BACKEND_URL`, `NODE_ENV=production`
- `NEXT_PUBLIC_*` are baked at image build time (pinned in the branch Dockerfile):
  publishable key, base URL, payload server URL. Changing them requires editing
  `Dockerfile` on `deploy/storefront` and pushing.

## First-run accounts

- Payload admin: created via REST `POST /api/users/first-register` (admin@hthmkt12.com).
  API key lives on that user (`enableAPIKey`). Auth header format:
  `Authorization: users API-Key <key>`.
- Medusa publishable key: seeded into DB table `api_key` (query it there if lost).

## Known Issues (TOSE platform)

1. Managed DB provisioning fails (~5 min timeout) — use external Postgres.
2. Rolling updates can wedge: new pod stays Pending while an old pod holds quota;
   `tose down -y` may not clean orphaned ReplicaSets from failed rollouts.
   Remedy: stop stale deployments via API, verify `Pods: 0/0`, then deploy once.
3. If the default domain 404s (Go-router text/plain 404) after a failed rollout,
   re-add it via `POST /projects/<slug>/domains`.
