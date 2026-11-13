# AGENTS

## Repository layout
- `app/`: Flutter client (`study_app`, Dart `>=3.3.0 <4.0.0`). Local learning archive/UI; data stays local (JSON/export), not uploaded.
- `server/`: TypeScript/Fastify asset service (Node `>=20`). PostgreSQL stores metadata/text; S3-compatible storage (MinIO/SeaweedFS) stores binary objects; binary access via presigned URLs.
- `doc/`: age/stage learning materials and design docs (many filenames are Chinese). Stage overview: `doc/readme.md`; cross-stage plan: `doc/分阶段学习方案.md`; subject framework: `doc/学科.md`.
- `.github/workflows/`: Flutter CI/build/release. CI Flutter version is pinned to `3.47.7` (`flutter-build.yml`); release tags `v*` must match `app/pubspec.yaml` `version`.

## App (`app/`) commands
Run from `app/`:
- `flutter pub get`
- `flutter analyze --no-fatal-infos` (matches CI; `analysis_options.yaml` uses `flutter_lints`, excludes platform/build dirs)
- `flutter test --reporter expanded` (unit/widget tests in `test/`)
- `flutter test integration_test/windows_flow_test.dart -d windows` for the Windows integration flow when a Windows desktop target is available
- `flutter run -d windows` for local desktop preview; `flutter build windows --release` / `flutter build apk --release` for release artifacts

CI/build gates are `flutter pub get` -> `flutter analyze --no-fatal-infos` -> `flutter test`.

## Server (`server/`) commands
Run from `server/`:
- `npm install`
- `copy .env.example .env` and fill required env vars (`src/config.ts` validates on startup; missing values fail fast)
- `npm run db:migrate` (requires reachable PostgreSQL/S3-compatible services)
- `npm run dev` (tsx watch, default `http://127.0.0.1:3000`), `npm run typecheck`, `npm run build`, `npm start`
- `docker compose up -d` starts local PostgreSQL 16 + MinIO per `docker-compose.yml` / `.env.example`
- DB helper scripts `db:up|db:down|db:status` use WSL (`wsl -d Arch -u root -- systemctl ... postgresql seaweedfs`); use only if that local environment exists, otherwise start services via Docker/your own setup.

No server lint or test scripts are defined in `package.json`; use `npm run typecheck` as the focused verification step.

## Implementation notes
- Prefer config/scripts/workflows as source of truth over prose docs when they differ (e.g. CI Flutter version, required commands).
- Preserve the app's local-first/privacy constraints described in `README.md` and `doc/design.md` (no upload of user archives; guidance based on local records).
- When editing curriculum docs under `doc/`, keep age-stage naming consistent with existing directories and link new overview docs from relevant indexes (`doc/readme.md`, stage `目录.md` files) as appropriate.
- Treat generated/build outputs and dependencies (`app/build/`, platform build dirs, `server/node_modules/`, `server/dist/`) as non-source unless the task explicitly targets them.
