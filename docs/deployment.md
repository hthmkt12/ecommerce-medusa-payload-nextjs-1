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

- **Medusa admin** (restored 2026-08-25): `admin@hthmkt12.com` — created directly
  in Supabase (`user` + `auth_identity` with `app_metadata.user_id` +
  `provider_identity` emailpass scrypt-kdf hash). Password was generated at
  recovery time; rotate it in `/dashboard` after first login. Login endpoint:
  `POST /auth/user/emailpass`.
- **Payload admin**: same email; password also reset during recovery — change on
  first login at `/admin`. API key rotation is done through the admin UI
  (Users → enableAPIKey); the key currently wired into the backend env was
  verified against the live CMS.
- Medusa publishable key: seeded into DB table `api_key`
  (query it there if lost).

## Sync status (verified 2026-08-25)

Full sync executed successfully against production:
products 4/4 and categories 4/4 landed in Payload (collections 0 = 0, matching
Medusa). Incremental sync fires via subscribers on product/category/collection
lifecycle events. To re-run a full sync:

```bash
TOKEN=$(curl -s -X POST https://hthmkt12-workspace-ecommerce.tose.sh/auth/user/emailpass \
  -H 'Content-Type: application/json' \
  -d '{"email":"admin@hthmkt12.com","password":"<pw>"}' | jq -r .token)

curl -X POST https://hthmkt12-workspace-ecommerce.tose.sh/admin/payload/sync/products \
  -H "Authorization: Bearer $TOKEN"
# repeat for /categories and /collections as needed
```

## Known Issues (TOSE platform)

1. Managed DB provisioning fails (~5 min timeout) — use external Postgres.
2. Rolling updates wedge when the project quota fits exactly one pod
   (e.g. 250m/512Mi): the surge pod stays Pending while the old pod holds all
   quota, rollout times out after 5m, and the platform marks the deployment
   failed while leaving BOTH pods behind. Confirmed root cause 2026-08-25.
   **Working remedy (API, not CLI)** — project quota must be free before a
   deploy can roll:
   a. `POST /api/workspaces/{ws}/projects/{slug}/deployments/{id}/stop` on the
      deployment that owns the Running pod (auth: `X-API-Key`, key from
      `~/.tose/config.json`; base `https://api-v2.tose.sh`).
   b. Verify `tose status <project>` shows `pods: 0/0`.
   c. Deploy once (`tose deploy <project>`). Brief downtime = build + roll.
   Notes:
   - `tose down -y` refuses when the *latest* deployment record is "failed"
     ("Latest deployment is already failed") even though an older pod holds
     quota; `tose restart` only bounces the old pod.
   - Stopping a deployment normally reaps its pod instantly (observed on CMS
     and backend), but at least one storefront ReplicaSet pod survived both
     stopDeployment and tose down and still serves traffic after >24h. That
     orphan consumes quota and blocks every new rollout; clearing it requires
     the TOSE dashboard/support (no CLI/API surface exposes it).
3. If the default domain 404s (Go-router text/plain 404) after a failed rollout,
   re-add it via `POST /projects/<slug>/domains`.
4. **Storefront rollout hang (open, needs TOSE support) — SITE DOWN since
   2026-08-26.** Every storefront deployment finishes building (~5 min, normal)
   then hangs at status `deploying` forever while creating ZERO pods (polled at
   20 s intervals through an entire rollout window: no Pending, no CrashLoop,
   nothing). Reproduced on a BRAND-NEW project after deleting the old one:
   - Old project `ecommerce-storefront` deleted (its slug remains reserved;
     recreate returns 409).
   - Fresh project `ecommerce-storefront-2` (id `da77962oa02fg29gmq8g`)
     created; git (`deploy/storefront`), env, and the public domain
     `hthmkt12-workspace-storefront.tose.sh` re-attached successfully.
   - Deployments `da779c2oa…`, `da779kaoa…`, `da77maqoa02ephpl8e90` all built
     then hung identically with empty `build_log` and no pod creation.
   Conclusion: TOSE deploy-worker defect between image build and k8s apply for
   this workspace/server (SGP1). Backend and CMS deploys on the same server
   rolled fine throughout, so it is specific to this pipeline path or project
   family. Ask TOSE support to inspect their deploy worker / the k8s
   Deployment `hthmkt12-workspace-ecommerce-storefront-2`; once fixed,
   `tose use hthmkt12-workspace/ecommerce-storefront-2 && tose up` ships the
   pending release (branch `deploy/storefront` @ `83e1ab0`).

## Operational notes (learned 2026-08-25)

- **Every push to a wired branch triggers an auto-deploy** (GitHub webhook).
  Combined with issue #2 above, pushing while a pod is Running will wedge that
  deploy. After any push, check `tose status`; if the webhook deploy failed,
  run the stop→0/0→deploy remedy.
- `PUT /projects/{slug}` accepts partial fields (e.g. `cpu`, `ram`) but makes
  `git_connection` disappear from subsequent GET responses even though the
  connection stays functional (manual builds still resolve the branch). There
  is no CLI/API surface to view or modify `auto_deploy` afterwards; reconnect
  via the dashboard if needed.
- `tose restart` kills and recreates pods of the current k8s Deployment but
  does not reap orphaned ReplicaSet pods either.
- Medusa backend container runs migrations before boot (`start.sh`), so first
  readiness can take longer than typical apps; keep the 5m rollout timeout in
  mind when deploying DB-heavy changes.

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
