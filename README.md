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

Como usar (desenvolvimento local, Windows)
1) Executar tudo automaticamente (Windows):
   - Abra PowerShell como Administrador (recomendado para hosts/mkcert) ou execute start-app.bat que solicitará elevação quando necessário.
   - Na raiz do repositório, execute:
     start-app.bat "uma_chave_forte_para_JWT"
   - O script irá:
     - instalar dependências do backend (npm install),
     - (opcional) mapear filmes-series.com para 127.0.0.1 no hosts,
     - (opcional) instalar/generar certificados mkcert em backend/certs/ para filmes-series.com,
     - iniciar o backend (HTTPS se certs presentes),
     - aguardar readiness e iniciar o app Flutter automaticamente (se flutter estiver no PATH).

2) Executar apenas o backend (manualmente):
   cd backend
   npm ci
   npm start

3) Testes de integração (local):
   cd backend
   npm run test:integration

Produção (expor para a internet, recomendado)
- Opção 1 — Docker Compose + Traefik (recomendado para automação TLS):
  1) Configure DNS para apontar seu domínio (ex: filmes-series.com) para o servidor público onde irá executar o Docker host.
  2) Crie um arquivo .env com as variáveis necessárias:
     DOMAIN=filmes-series.com
     LETSENCRYPT_EMAIL=you@example.com
     JWT_SECRET=uma_chave_forte
     ADMIN_USER=nome_admin
     ADMIN_PASS=senha_forte
  3) Execute:
     docker compose -f docker-compose.prod.yml up --build -d
  - O Traefik neste compose tentará obter certificados Let's Encrypt automaticamente para DOMAIN. Certifique-se de que a porta 80/443 do servidor estão abertas e que o domínio resolve para o servidor.

- Opção 2 — Docker Compose simples (local/VM):
  - docker compose up --build -d
  - O arquivo docker-compose.yml monta backend/data em ./backend/data, garantindo persistência do SQLite DB entre reinícios.

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
- GET /auth/me  -> Authorization: Bearer <token>
- POST /auth/refresh -> { refreshToken }
- POST /auth/logout -> { refreshToken }
- POST /admin/backup -> (admin only) cria backup do DB em backend/data/backups/

Suporte e próximos passos
- Posso automatizar Docker Compose para montar certificados gerados por mkcert e ajustar nginx reverse-proxy, mover nodemon para devDependencies e criar multi-stage Dockerfile para imagens de produção mais leves.
- Posso também adicionar integração com um banco relacional (Postgres) e um workflow de CI/CD que publica imagens no Docker Hub / GitHub Package Registry (requer credenciais de registro).

Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>