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
   Confirmed 2026-08-25: `tose down` refuses when the *latest* deployment record
   is "failed" ("Latest deployment is already failed") even though a pod from an
   *earlier* deployment still holds quota; `tose restart` only bounces the old
   pod. Clearing the stale deployment requires the dashboard/API — the CLI alone
   cannot recover from this state.
3. If the default domain 404s (Go-router text/plain 404) after a failed rollout,
   re-add it via `POST /projects/<slug>/domains`.

## Build-time vs runtime env

- Payload CMS: `src/payload.config.ts` fails fast when `PAYLOAD_SECRET` /
  `DATABASE_URI` are missing at runtime boot, but skips enforcement during
  `next build` (`NEXT_PHASE === 'phase-production-build'`) — page data
  collection imports the config without secrets present.
- Medusa backend: `medusa-config.ts` refuses to boot in production without
  `JWT_SECRET`, `COOKIE_SECRET`, `PAYLOAD_API_KEY`. The root Dockerfile must
  NOT set `NODE_ENV=production` before its `pnpm run build` step or image
  builds fail; NODE_ENV is supplied by the runtime environment only.

## PAYLOAD_API_KEY rotation (discovered 2026-08-25)

The key recorded in git history (`cc946fdd-…`) does NOT authenticate against
the live CMS (`/api/users/me` → `{user: null}`, collection reads → 403), most
likely because `PAYLOAD_SECRET` changed after the key was created — Payload
stores keys as HMAC-SHA256(payload.secret, key), so rotating the secret
invalidates every stored key hash. Medusa→Payload sync was therefore already
broken before the auth hardening landed. Recovery sequence:

1. Deploy the updated CMS, log into `/admin`.
2. Users → admin user → generate a new API key (enableAPIKey).
3. Set `PAYLOAD_API_KEY` on TOSE project `ecommerce` → redeploy backend.
4. Verify sync (edit a product, confirm it lands in CMS), then discard the old
   key value everywhere (local `.env` already regenerated).
