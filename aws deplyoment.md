# AWS Deployment

Date started: 2026-08-21
Last updated: 2026-08-27

## Purpose
Record steps taken, findings, and next actions for deploying this repo to AWS (ECR + ECS Fargate via GitHub Actions + Terraform). This file is kept up to date as an ongoing log — every challenge hit and the fix applied gets recorded here.

## Architecture (current)

- **Repos**:
  - `kunalgupta91/reos` (this repo) — deploy-only: Terraform infra, GitHub Actions workflow, deploy scripts. No app source.
  - `kunalgupta91/re-os-code` (new, public) — monorepo containing `crm-web`, `crm-backend`, `crm-ai-service` source. Consolidated from three separate private repos (`re-os-crm/crm-web`, `re-os-crm/crm-backend`, `re-os-crm/crm-ai-service`) which are now retired; `re-os-code` is the actively-developed repo going forward.
  - The CI workflow in `reos` checks out `re-os-code` (public, no token needed) into `src/` and builds each service's Docker context from there.

- **AWS (account 071954286641, region ap-south-1)**:
  - ECR: `reos/crm-web`, `reos/crm-backend`, `reos/crm-ai-service`
  - ECS Fargate cluster `reos-cluster` running three services: `crm-web-service` (public, behind ALB), `crm-backend-service` and `crm-ai-service-service` (private, reachable only via Cloud Map service discovery on `*.reos.local`)
  - RDS Postgres `db.t4g.micro` (`reos-db`) for `crm-backend`, private, SSL required
  - Application Load Balancer (`reos-crm-web-alb`) — only `crm-web` is public
  - IAM: GitHub OIDC provider + `reos-github-actions-deploy-role` (assumed by CI, no long-lived AWS keys in GitHub), plus ECS task execution/task roles
  - CloudWatch log groups per service (`/ecs/crm-web`, `/ecs/crm-backend`, `/ecs/crm-ai-service`)

- **Secrets** (GitHub Actions secrets on `kunalgupta91/reos`, injected as plaintext container env — chosen over Secrets Manager for simplicity): `AWS_ROLE_TO_ASSUME`, `ECS_TASK_EXEC_ROLE`, `ECS_TASK_ROLE`, `DATABASE_URL`, `JWT_PRIVATE_KEY`, `JWT_PUBLIC_KEY`, `AI_SERVICE_KEY`.

## Status: LIVE

crm-web is publicly reachable at `http://reos-crm-web-alb-1493556412.ap-south-1.elb.amazonaws.com` and serving the app correctly. crm-backend connects to RDS and starts cleanly with all routes mapped. crm-ai-service starts cleanly with all routers (including pricing) wired up. All three ECS services report `desired: 1, running: 1`, steady state confirmed after rollout settled.

## Challenges hit and fixes applied (chronological)

1. **No git repo, no CLI tools locally.** This machine had no `git`, `terraform`, `aws`, or `gh` set up for this project. → Installed Terraform, AWS CLI, and GitHub CLI via `winget`. Initialized git, authenticated `aws configure` and `gh auth login` (both done interactively by the user).

2. **`reos-admin` IAM user lacked EC2/RDS/ALB permissions.** `terraform plan` failed on `ec2:DescribeVpcs` — the user only had narrow ECR/ECS permissions from an earlier setup. → User attached `AdministratorAccess` to `reos-admin` via the AWS Console.

3. **Terraform only provisioned ECR + a bare ECS cluster — no VPC wiring, no ECS *services*, no database.** The workflow's `aws ecs update-service` calls would have failed immediately (services didn't exist), and `crm-backend` needs Postgres/JWT keys that didn't exist anywhere. → Built out `infra/terraform`: security groups, a public ALB for `crm-web` only, Cloud Map service discovery for `crm-backend`/`crm-ai-service` (private), an RDS Postgres instance, CloudWatch log groups, and bootstrap ECS task definitions + services (with `lifecycle { ignore_changes = [task_definition] }` so CI owns real revisions after the first deploy).

4. **crm-backend port mismatch.** Task def mapped container port 3001 but the app defaults to `PORT=3000`. → Added explicit `PORT` env vars per service in the workflow's task-def JSON.

5. **Three services were three separate private repos (`re-os-crm/*`), but the workflow assumed one monorepo checkout.** → After discussion, consolidated into one new public repo `kunalgupta91/re-os-code` (decided: this becomes the real repo going forward; old repos retired). Public was chosen so CI needs no PAT/token for checkout. Ran a secrets audit before making it public (clean — see below).

6. **Pre-publish secrets audit.** Scanned all three services for hardcoded credentials before making `re-os-code` public. Found nothing blocking — only obvious test fixtures and safe env-var fallbacks. Verdict: safe to publish.

7. **OIDC `id-token: write` permission missing.** `configure-aws-credentials` failed with "Could not load credentials from any providers" — GitHub denies OIDC token issuance by default. → Added `permissions: { id-token: write, contents: read }` to the job.

8. **OIDC trust policy didn't match GitHub's actual `sub` claim format.** Still got "Not authorized to perform sts:AssumeRoleWithWebIdentity" after the permission fix. Added a temporary debug step to decode the real token — GitHub's `sub` claim is `repo:kunalgupta91@111513933/reos@1342088284:ref:refs/heads/main` (includes immutable numeric owner/repo IDs), not the plain `repo:kunalgupta91/reos:*` the Terraform trust policy expected. → Widened the `StringLike` condition to match both `repo:OWNER/REPO:*` and `repo:OWNER@*/REPO@*:*`. Removed the debug step afterward.

9. **`crm-web` build failed: ESLint `no-unused-vars` errors.** `next build` runs lint as part of the production build. `SalesTargetsResponseSchema`/`SalesTargetSchema` (and their now-orphaned `zod` import) in `src/app/api/sales-targets/route.ts`, and an unused `allOf` import in `src/lib/import/units.tsx`, were dead code. → Removed them. Verified with a full local `npm run build` before pushing again to avoid further round-trips.

10. **`crm-web` Dockerfile referenced `next.config.js`, but the project uses `next.config.mjs`.** → Fixed the `COPY --from=builder` path in the Dockerfile.

11. **`crm-web` Dockerfile also failed on `COPY --from=builder /app/public`** — the project has no `public/` directory at all. → Added `crm-web/public/.gitkeep` so the directory exists.

12. **`AWS_ACCOUNT_ID: 071954286641` was unquoted in the workflow's `env:` block.** YAML parsed it as a numeric literal and stripped the leading zero everywhere it was interpolated (`71954286641`, 11 digits) — image tags pointed at a nonexistent ECR host, causing `docker push` to fail with "no basic auth credentials" (Docker had no stored login for that wrong hostname). → Quoted it as a string: `AWS_ACCOUNT_ID: "071954286641"`.

13. **Several GitHub secrets got a leading UTF-8 BOM (`﻿`) baked in.** Root cause: `"value" | gh secret set NAME` in PowerShell pipes the string to the native process's stdin using an encoding that prepends a BOM. This silently corrupted `DATABASE_URL`, `JWT_PRIVATE_KEY`, `JWT_PUBLIC_KEY`, and `AI_SERVICE_KEY`. Symptom: `crm-backend` failed DNS resolution with `getaddrinfo ENOTFOUND base` — the BOM broke the Postgres connection-string parser. Diagnosed by pulling the live task definition (env vars are stored in plaintext by design) and inspecting byte-for-byte. → Re-set all affected secrets using `gh secret set NAME -b "$value"` (direct argument, not piped through stdin) instead. **Lesson: always use `-b`/`--body` with `gh secret set` on Windows PowerShell, never pipe.**

14. **RDS rejected connections even with the BOM fixed.** `no pg_hba.conf entry for host ..., no encryption` — AWS RDS Postgres requires SSL by default (`rds.force_ssl`), and the app's `DATABASE_URL` had no `sslmode`. → Appended `?sslmode=no-verify` to the Terraform-generated `database_url` output (accepts the RDS server cert without needing to bundle the RDS CA chain). Required `terraform apply` to refresh — `terraform output` reads from state, not live from `.tf` files, so editing `outputs.tf` alone doesn't change what `terraform output` returns until you apply.

15. **`crm-ai-service` container crash-looped: `exec: "uvicorn": executable file not found in $PATH`.** The Dockerfile's final stage only copied `/usr/local/lib/python3.11/site-packages` from the builder stage — `pip install`'s CLI entry-point scripts (like `uvicorn`) land in `/usr/local/bin`, which was never copied. → Added `COPY --from=builder /usr/local/bin /usr/local/bin` to the final stage.

16. **`crm-ai-service` started but then crashed on import: `ModuleNotFoundError: No module named 'pricing.router'`.** `main.py` imports `pricing.router`, but `pricing/router.py`, `pricing/schemas.py`, and `pricing/__init__.py` didn't exist at all — `pricing/predictor.py` itself was already broken (importing from the nonexistent `pricing.schemas`). This was a real incomplete feature in the source, not a deploy/config bug, so it wasn't something to paper over by guessing an API shape. → Found `tests/test_pricing.py` already specified the exact expected schema (including a `bathrooms` field on `UnitFeatures` and `price_range` as a plain dict, not a nested model) — wrote `pricing/schemas.py` and `pricing/router.py` to match that spec exactly, following the same router/schemas pattern as the sibling `churn/` module. Wired `pricing_router` back into `main.py`.

## Key lessons for next time

- **Never pipe secret values into `gh secret set` from PowerShell** — it silently injects a UTF-8 BOM. Always use `-b "$value"`.
- **Quote numeric-looking strings in YAML** (account IDs, zip codes, phone numbers) — unquoted, a leading zero gets silently stripped.
- **`terraform output` reads from state, not config** — an edited `outputs.tf` needs an `apply` before `terraform output` reflects it, even if no real resources changed.
- **GitHub's OIDC `sub` claim now includes immutable owner/repo IDs** (`repo:OWNER@ID/REPO@ID:...`), not just names — trust policies written against the plain `repo:OWNER/REPO:*` pattern from older tutorials will silently fail with "Not authorized" and no other clue. Decode the actual token (temporary debug step) if this happens again.
- **Multi-stage Docker builds for Python apps must copy `/usr/local/bin`, not just `site-packages`** — pip's CLI entry points live there.
- **`next build` runs ESLint** — unused-var errors that are invisible in dev fail the production Docker build.
- **Existing test files are a free spec** — when reconstructing a missing module, check for a matching `tests/test_*.py` first; it often pins the exact field names/shapes needed, catching mismatches (like a missing `bathrooms` field) before another deploy round-trip.
- **A CI workflow triggered on every push to `main` will also fire on doc-only commits** — added `paths-ignore: ['**.md']` to skip wasted rebuilds; watch for two runs racing if you forget and push mid-deploy (cancel the redundant one).

## Remaining / possible follow-ups (not yet done, not blocking)

- IAM policy for `reos-github-actions-deploy-role` is still broad (`ecr:*`, `ecs:*`, `ec2:Describe*` on `*`) — fine for now, worth tightening later.
- `sslmode=no-verify` skips RDS server certificate validation. Fine for now; switching to `verify-full` with the RDS CA bundle would be a hardening step later.
- No HTTPS/custom domain on the ALB yet (plain HTTP on port 80).
- `reos-admin` IAM user now has full `AdministratorAccess` — broader than needed; could be scoped down later.
- `pricing/predictor.py`'s heuristic model and `pricing/recommender.py`'s market-signal model are simple rules-based logic (not ML) — fine as a first cut, worth revisiting if real pricing data becomes available.
