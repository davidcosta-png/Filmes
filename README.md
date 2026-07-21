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
- Há scripts úteis para Windows incluídos no repositório:
  1) backend\start.bat [JWT_SECRET]
     - Instala dependências (npm install) se necessário e inicia o backend em uma nova janela.
     - Parâmetro opcional: forneça um JWT secret para a sessão do processo. Ex:
       backend\start.bat "uma_chave_forte_aqui"

  2) backend\start-backend.ps1 [JWT_SECRET]
     - PowerShell helper que tenta instalar Node.js via winget (se npm não estiver disponível), executa npm install e inicia o servidor em uma janela separada.
     - Uso:
       powershell -ExecutionPolicy Bypass -File backend\start-backend.ps1 -jwtSecret "uma_chave_forte_aqui"

  3) start-app.bat [JWT_SECRET]
     - Script na raiz que chama backend\start.bat e tenta iniciar o app Flutter se "flutter" estiver no PATH. Ex:
       start-app.bat "uma_chave_forte_aqui"

- Observações sobre emuladores e URLs:
  - Se você executar o backend no host e testar o app em um emulador Android, substitua a base URL em lib/services/auth_service.dart por http://10.0.2.2:4000 (esse endereço mapeia localhost do host para o emulador Android).
  - Para emulador iOS (simulador macOS) ou execução desktop/web use http://localhost:4000.

- Em produção: substituir armazenamento JSON por banco de dados, proteger o JWT secret em variáveis de ambiente e configurar HTTPS.

Docker (opcional)
- Há um Dockerfile para o backend em backend/Dockerfile e um docker-compose.yml na raiz para facilitar testes locais.
  - Como usar:
    1) Defina a variável JWT_SECRET localmente (opcional):
       - Windows PowerShell: $env:JWT_SECRET = 'uma_chave_forte_aqui'
       - Linux/macOS: export JWT_SECRET=uma_chave_forte_aqui
    2) Rodar docker-compose:
       docker compose up --build -d
    3) O backend ficará disponível em http://localhost:4000

Admin padrão criado automaticamente
- Um usuário administrador padrão é criado automaticamente se não existir um admin no backend.
  - Credenciais iniciais (teste/protótipo):
    Usuário: Davi
    Senha: 1234
  - IMPORTANTE: Mude essa senha imediatamente em ambientes de teste/produção.

Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com> 