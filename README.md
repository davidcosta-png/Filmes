Stream Aggregator — Prototype (Flutter)

Objetivo
- Scaffold protótipo para um agregador cross-platform (mobile, desktop, web, TV via Flutter).
- MVP inclui: autenticação local simples, abas/categorias, tema claro/escuro, busca via TMDB (exemplo), painel admin básico.

Requisitos
- Flutter SDK instalado (Windows): https://docs.flutter.dev/get-started/install/windows
- Versão mínima do Dart/Flutter conforme seu SDK.

Como usar
1. Instalar Flutter conforme o link acima e adicionar ao PATH.
2. Abrir um terminal na pasta do projeto:
   C:\Users\Usuário\Documents\Projet\stream_aggregator
3. Copiar o arquivo de configuração de exemplo:
   cd lib
   copy config.sample.dart config.dart
   Editar lib\config.dart e colocar sua chave TMDB em TMDB_API_KEY
4. Obter dependências e rodar:
   flutter pub get
   flutter run

Notas importantes
- Este é um protótipo: não tenta "agregar" streams de plataformas proprietárias. Em vez disso, mostra como estruturar:
  - Autenticação local (SharedPreferences)
  - Abas por categoria
  - Temas (dark/light)
  - Busca usando a API pública do TMDB (metadados em pt-BR)
- Para integrar streams legítimos, será necessário implementar:
  - Contratos/licenças com provedores de conteúdo
  - Proxies/serviços server-side para gerenciar credenciais e DRM

Admin e usuários
- Conta admin de teste incluída: usuário=admin senha=admin (apenas protótipo)
- Em produção implementar backend com controle de usuários, roles e políticas de bloqueio/pausa.

Próximos passos sugeridos
- Implementar backend (Node/Django/Go) com autenticação, controle de usuários e links oficiais
- Implementar player com suporte a DRM (Widevine/PlayReady) para conteúdo protegido
- Criar sistema de coleta de metadados e catálogo (crawlers / APIs oficiais)

Se quiser, posso:
- Gerar o restante das telas (catálogo com tiles, player, perfil de usuário)
- Criar um backend de exemplo com autenticação e CRUD de usuários (já incluso em backend/)
- Ajudar com o fluxo de licenciamento e arquitetura de produção

Backend (protótipo)
- Há um scaffold simples em backend/ com Express que implementa: criação de usuários, login (bcrypt + JWT), listagem e pausa de usuários via users.json.
- Para rodar o backend (exemplo):
  cd backend
  npm install
  node index.js
  (ou use o helper PowerShell backend\start-backend.ps1)
- Deve ficar disponível em https://filmes-series.com

Testes rápidos com curl (exemplos)
- Login (gera token + refreshToken):
  curl -X POST https://filmes-series.com/auth/login -H "Content-Type: application/json" -d "{\"username\":\"Davi\",\"password\":\"1234\"}"
- Introspecção (me):
  curl https://filmes-series.com/auth/me -H "Authorization: Bearer <TOKEN>"
- Refresh (rotaciona refresh token):
  curl -X POST https://filmes-series.com/auth/refresh -H "Content-Type: application/json" -d "{\"refreshToken\":\"<REFRESH_TOKEN>\"}"
  - Verifique que backend grava o novo refreshToken corretamente.
- Logout (revoga refresh token):
  curl -X POST https://filmes-series.com/auth/logout -H "Content-Type: application/json" -d "{\"refreshToken\":\"<REFRESH_TOKEN>\"}"

Local testing with filmes-series.com (recommended)
- To test locally using the domain filmes-series.com, map the domain to localhost in your hosts file and (optionally) configure TLS for local HTTPS:

  1) Edit hosts file (requires admin privileges):
     - Windows: edit C:\Windows\System32\drivers\etc\hosts and add:
       127.0.0.1 filmes-series.com
     - macOS / Linux: edit /etc/hosts and add:
       127.0.0.1 filmes-series.com

  2) Start the backend (example):
     cd backend
     npm install
     npm start

  3) Configure the frontend to use lib/config.dart (BACKEND_BASE). By default BACKEND_BASE is set to https://filmes-series.com in lib/config.dart. If you do not intend to use HTTPS locally, change it to http://localhost:4000 or http://10.0.2.2:4000 for Android emulator.

  Optional: enable HTTPS locally with mkcert (recommended if you use HTTPS in the app):
  - Install mkcert: https://github.com/FiloSottile/mkcert
  - Run: mkcert -install
  - Generate certs: mkcert filmes-series.com
  - Use a small reverse proxy (nginx) or Docker to serve the backend with the generated certs and the filmes-series.com hostname.

Observações:
- O backend cria um admin inicial (Davi / 1234) se nenhum admin existir — altere essa senha ao rodar em dev/produção.
- Em produção, defina o env JWT_SECRET em vez do valor padrão.

2) Frontend (Flutter)
- No diretório raiz do projeto:
  flutter pub get
  flutter run
- Se testar no emulador Android, ajustar base em lib/config.dart para:
  const String BACKEND_BASE = 'http://10.0.2.2:4000';
  (ou mantenha https://filmes-series.com se estiver apontando para o domínio)

Segurança e recomendações imediatas
- Trocar o JWT_SECRET para um valor seguro via variável de ambiente.
- Alterar a senha do admin padrão criado automaticamente.
- Em produção, usar um banco de dados real em vez de persistir em users.json.
- Mover nodemon para devDependencies (se for construir imagem de produção).

Próximos passos que posso executar (você já escolheu manter no main)
- Posso adicionar um snippet no README com os comandos curl e instruções de execução (recomendado).
- Posso criar testes de integração (ex.: script Node ou pequenos testes automatizados) para cobrir login → refresh → logout e adicionar CI.
- Posso criar uma branch/PR se preferir fluxos baseados em PR.

Deseja que eu:
- adicione o snippet de README com os comandos e instruções de execução? (recomendado)
- crie testes de integração e um workflow de CI para validar login/refresh/logout automaticamente?
Diga qual opção prefere ou peça outra ação — se quiser, já adiciono o README com os passos de execução local.

Backend (protótipo)
- Há um scaffold simples em backend/ com Express que implementa: criação de usuários, login (bcrypt + JWT), listagem e pausa de usuários via users.json.
- Para rodar o backend (exemplo):
  cd backend
  npm install
  node index.js
  (ou use o helper PowerShell backend\start-backend.ps1)
- Deve ficar disponível em https://filmes-series.com

Docker (opcional)
- Há um Dockerfile para o backend em backend/Dockerfile e um docker-compose.yml na raiz para facilitar testes locais.
  - Como usar:
    1) Defina a variável JWT_SECRET localmente (opcional):
       - Windows PowerShell: $env:JWT_SECRET = 'uma_chave_forte_aqui'
       - Linux/macOS: export JWT_SECRET=uma_chave_forte_aqui
    2) Rodar docker-compose:
       docker compose up --build -d
    3) O backend ficará disponível em https://filmes-series.com

Admin padrão criado automaticamente
- Um usuário administrador padrão é criado automaticamente se não existir um admin no backend.
  - Credenciais iniciais (teste/protótipo):
    Usuário: Davi
    Senha: 1234
  - IMPORTANTE: Mude essa senha imediatamente em ambientes de teste/produção.
