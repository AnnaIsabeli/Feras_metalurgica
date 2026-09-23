# Fera Metalúrgica — ORCEX

Aplicativo do Projeto Integrador para solicitações, precificação e acompanhamento de orçamentos.

**Entrega atual: esqueleto da arquitetura com uma primeira integração de solicitações.**
Login Google, precificação, propostas e pedidos completos ainda estão no roadmap.
O protótipo Figma não foi alterado nesta entrega.

## Estrutura

```text
apps/mobile/          Flutter: telas → view models → repositórios → HTTP
services/api/         Dart/Shelf: HTTP → serviços → repositórios → PostgreSQL
packages/contracts/   Modelos JSON compartilhados, sem segredos ou regras de preço
database/migrations/  Evolução versionada do banco
database/seeds/       Usuários de demonstração local
docs/                 Arquitetura, API, roadmap e validação
scripts/              Preparação da demonstração
.github/workflows/    Análise e testes automáticos
```

O Flutter **não conecta diretamente ao banco**. A API valida identidade, permissões e dados.
Usamos um backend único organizado por módulos, sem microsserviços nesta fase.

## Implementado

- Tema e navegação Flutter por perfil; formulário, carregamento, erro, lista vazia e nova tentativa.
- Comprador cria/lista suas solicitações; vendedor aprovado consulta solicitações.
- API de saúde, disponibilidade do banco, identidade e solicitações.
- PostgreSQL com consultas parametrizadas, chaves estrangeiras e restrições.
- Identidade substituível por Google; modo padrão nega acesso privado.
- Testes de autorização, validação, isolamento por comprador e estado da interface.

## Demonstração local

Requisitos: Flutter stable com Dart >=3.8, Docker Desktop com engine Linux rodando, Git e Chrome.

1. Copie `.env.example` para `.env`. Configure uma senha local alfanumérica (caracteres especiais
   na URL do PostgreSQL precisam ser codificados).
2. Na raiz do repositório, execute no PowerShell:

```powershell
./scripts/demo.ps1
```

Isso inicia PostgreSQL/API e insere usuários demonstrativos. Confira `http://localhost:8080/ready`.
O banco não publica porta para fora da rede Docker.

3. Inicie o aplicativo:

```powershell
cd apps/mobile
flutter pub get
flutter run -d chrome --web-port 5000 --dart-define=ENABLE_DEMO=true
```

Entre como comprador, crie uma solicitação, saia da demonstração e entre como vendedor para
consultá-la. Os dados permanecem no PostgreSQL.

O modo local aceita `demo-buyer` e `demo-seller`: **não são autenticação de produção**.
A API só aceita esses tokens com `APP_ENV=development` e `DEV_AUTH_ENABLED=true`.
A interface exige `ENABLE_DEMO=true`. Sem essas opções o acesso demonstrativo fica desativado.
Não exponha esse modo na internet.

### Android

O host Android deve ser gerado pelo SDK oficial antes da primeira execução:

```powershell
cd apps/mobile
flutter create --platforms=android --project-name fera_mobile --org br.edu.fera .
flutter run --dart-define=ENABLE_DEMO=true --dart-define=API_BASE_URL=http://10.0.2.2:8080
```

Android ainda precisa de validação no emulador, inclusive permissão de internet e política HTTP
de desenvolvimento. Produção exige HTTPS. O primeiro alvo de demonstração é web.

### Parar preservando os dados

```powershell
docker compose down
```

Migrações iniciais rodam apenas em volume vazio. Atualizações futuras exigem novas migrações;
não apague um volume com dados reais para atualizar o esquema.

## Testar

```powershell
cd services/api
dart pub get
dart analyze --fatal-infos
dart test
cd ../../apps/mobile
flutter pub get
flutter analyze
flutter test
flutter build web
```

O teste PostgreSQL exige `TEST_DATABASE_URL` apontando para base de teste com migração e seed.
Sem essa variável ele é ignorado, não aprovado. O GitHub Actions prepara essa base.

- [Arquitetura](docs/ARCHITECTURE.md)
- [API implementada](docs/API.md)
- [Regras e motor de precificação — Sprint 2](docs/PRICING.md)
- [Validação e limitações](docs/VALIDATION.md)
