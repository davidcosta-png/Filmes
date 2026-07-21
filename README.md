Stream Aggregator — Prototype (Flutter)

Objetivo
- Scaffold protótipo para um agregador cross-platform (mobile, desktop, web, TV via Flutter).
- MVP inclui: autenticação local simples, abas/categorias, tema claro/escuro, busca via TMDB (exemplo), painel admin básico.

Requisitos
- Flutter SDK instalado (Windows): https://docs.flutter.dev/get-started/install/windows
- Node.js (LTS) para o backend: https://nodejs.org/
- Docker & Docker Compose (opcional, para produção/local Docker).

Visão geral das mudanças importantes
- O backend agora usa SQLite (better-sqlite3) para armazenar usuários e refresh tokens em backend/data/users.db — isso garante persistência mesmo se o processo ou servidor cair.
- Scripts e docker-compose foram atualizados para facilitar execução em desenvolvimento e produção (traefik optional para TLS/Let's Encrypt).
- Há automação para configurar hosts/mkcert no Windows via backend/start-backend.ps1 e um wrapper start-app.bat para iniciar backend + Flutter em sequência.

Key recent additions
- Migration script: backend/migrate-sqlite-to-postgres.js — copies users from existing SQLite DB to Postgres (idempotent upsert).
- Scheduled encrypted backups: docker-compose.prod.yml includes a backup-runner service that runs backup-and-upload.js periodically (interval via BACKUP_INTERVAL_SECONDS, default once per day).
- CLI backup: npm run backup in backend will produce encrypted backup (if BACKUP_KEY set) and upload to S3 if BACKUP_S3_BUCKET is configured.

How to migrate existing local data to Postgres (one-time)
1) Ensure you have a Postgres server and set POSTGRES_URL or use docker-compose.prod.yml (it provides a postgres service).
2) If using docker-compose.prod.yml locally, set .env with POSTGRES_USER/POSTGRES_PASSWORD/POSTGRES_DB and run:
   docker compose -f docker-compose.prod.yml up -d postgres
3) Run the migration script (locally or in a container that has access to both DBs):
   cd backend
   npm ci
   POSTGRES_URL="postgresql://user:pass@host:5432/dbname" node migrate-sqlite-to-postgres.js
4) After migration, point backend to Postgres in production by setting POSTGRES_URL (or using docker compose which sets it automatically).

Scheduled backups (production)
- The docker-compose.prod.yml includes a backup-runner service. Configure these env vars in your .env or orchestration:
  - BACKUP_S3_BUCKET (optional) — if set, backups are uploaded to S3
  - AWS_REGION (required for S3 upload)
  - BACKUP_KEY (recommended) — 32-byte key in base64 or hex to encrypt backups
  - BACKUP_S3_PREFIX (optional) — prefix in bucket
  - BACKUP_INTERVAL_SECONDS (optional) — default 86400 (once per day)

To run backups manually:
  cd backend
  npm run backup

Migration, HA and production notes
- For high availability, use a managed Postgres service and run multiple backend replicas behind a load balancer.
- The backup system will produce encrypted backups if BACKUP_KEY provided. Keep BACKUP_KEY secure and rotate as needed.

All changes committed to main branch. See backend/ for scripts and docker-compose.prod.yml for production deployment.

Persistência e resiliência das credenciais de administrador
- A migração para SQLite (backend/data/users.db) significa que as credenciais de administrador permanecem em disco e não são perdidas se o processo cair.
- Recomenda-se montar backend/data em um volume persistente (host bind mount ou volume) em qualquer ambiente onde a disponibilidade importa.
- Para maior resiliência (e compartilhamento entre múltiplas instâncias), use um banco de dados gerenciado (Postgres/MySQL) — alterações necessárias no código serão pequenas (trocar camada de persistência).
- O compose de produção permite definir ADMIN_USER/ADMIN_PASS via variáveis de ambiente para garantir que um admin conhecido exista ao iniciar o serviço.

Backup e restauração
- Backup rápido (Windows PowerShell):
  cd backend
  .\backup-db.ps1  # cria backend/data/backups/users-YYYY-MM-DD_HH-MM-SS.db
- Backup com batch wrapper:
  cd backend
  backup-db.bat
- Para restaurar: pare o serviço, substitua backend/data/users.db pelo arquivo de backup desejado e inicie novamente.

Segurança e recomendações
- Alterar imediatamente o JWT_SECRET e a senha do admin em ambientes públicos.
- Nunca comitar chaves ou senhas reais neste repositório.
- Em produção, prefira banco gerenciado (Postgres) e segredos via secret manager.

Endpoints úteis
- POST /auth/login  -> { username, password }
- GET /auth/me  -> Authorization: ******
- POST /auth/refresh -> { refreshToken }
- POST /auth/logout -> { refreshToken }
- POST /admin/backup -> (admin only) cria backup do DB em backend/data/backups/

Suporte e próximos passos
- Posso automatizar Docker Compose para montar certificados gerados por mkcert e ajustar nginx reverse-proxy, mover nodemon para devDependencies e criar multi-stage Dockerfile para imagens de produção mais leves.
- Posso também adicionar integração com um banco relacional (Postgres) e um workflow de CI/CD que publica imagens no Docker Hub / GitHub Package Registry (requer credenciais de registro).

Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>
