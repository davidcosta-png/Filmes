Backend prototype (Node/Express)

Instalação e execução (exemplo):

1. Abra terminal em backend\
2. npm install
3. node index.js   (ou npm start)

API endpoints (protótipo):
- POST /auth/login  { username, password } -> { token }
- GET  /users        -> list users (username, role, paused)
- POST /users        { username, password, role } -> create user
- POST /users/:username/pause { paused: true|false } -> pause/unpause user

Observações:
- Armazena usuários em users.json (protótipo). Em produção use um banco de dados.
- Rotas de gerenciamento de usuários estão protegidas por JWT e exigem role=admin.
- Endpoints adicionais para refresh token e logout foram adicionados:
  - POST /auth/refresh { refreshToken } -> { token, refreshToken }
  - POST /auth/logout { refreshToken } -> { ok: true }
- Se um usuário for pausado via /users/:username/pause, seu refresh token será revogado imediatamente, impedindo novo acesso.
- Defina a variável de ambiente JWT_SECRET para configurar o segredo em produção (o projeto usa um valor padrão para desenvolvimento).
- Admin inicial: será criado automaticamente com senha 'admin' na primeira execução.

Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com> 