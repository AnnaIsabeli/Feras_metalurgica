# Sistema de Estacionamento

Aplicação web completa para gerenciamento de estacionamento desenvolvida com:

- **Backend**: Java 8 puro (`HttpServer` nativo + JDBC + Gson)
- **Frontend**: HTML5, CSS3, Vanilla JavaScript
- **Banco de dados**: PostgreSQL
- **Infraestrutura**: Docker Compose + Nginx

---

## Pré-requisitos

- Docker >= 20.x
- Docker Compose >= 2.x

---

## Executar o projeto

```bash
docker compose up --build -d
```

A primeira execução faz o download das imagens e compila o backend com Maven (~3 min).

| Serviço     | Endereço                     |
|-------------|------------------------------|
| Frontend    | http://localhost:3000        |
| Backend API | http://localhost:8080        |
| PostgreSQL  | localhost:5432               |

---

## Parar os containers

```bash
docker compose down
```

Para remover os dados do banco junto:

```bash
docker compose down -v
```

---

## Estrutura

```
estacionamento/
├── backend/          Java 8 — API REST
│   ├── src/
│   ├── pom.xml
│   └── Dockerfile
├── frontend/         HTML + CSS + JS — Nginx
│   ├── index.html
│   ├── css/
│   ├── js/
│   ├── nginx.conf
│   └── Dockerfile
├── database/
│   └── init.sql      Schema + dados iniciais
├── docker-compose.yml
└── .env.example
```

---

## Execução local (sem Docker)

### Pré-requisitos

| Ferramenta | Versão mínima | Download |
|------------|---------------|---------|
| JDK | 8 | https://adoptium.net |
| Maven | 3.6 | https://maven.apache.org/download.cgi |
| PostgreSQL | 13+ | https://www.postgresql.org/download |
| Nginx | qualquer | https://nginx.org/en/download.html (Mac: `brew install nginx`) |

---

### 1. Banco de dados

**Mac (Homebrew)**
```bash
brew install postgresql@15
brew services start postgresql@15
createdb estacionamento
psql estacionamento < database/init.sql
```

**Windows**
```
# Após instalar o PostgreSQL, abra o psql como postgres:
psql -U postgres
CREATE DATABASE estacionamento;
\q
psql -U postgres -d estacionamento -f database\init.sql
```

---

### 2. Backend

Dentro da pasta `backend/`:

**Mac**
```bash
export DB_HOST=localhost
export DB_PORT=5432
export DB_NAME=estacionamento
export DB_USER=postgres
export DB_PASSWORD=postgres

mvn package -DskipTests
java -jar target/estacionamento.jar
```

**Windows (cmd)**
```cmd
set DB_HOST=localhost
set DB_PORT=5432
set DB_NAME=estacionamento
set DB_USER=postgres
set DB_PASSWORD=postgres

mvn package -DskipTests
java -jar target\estacionamento.jar
```

**Windows (PowerShell)**
```powershell
$env:DB_HOST     = "localhost"
$env:DB_PORT     = "5432"
$env:DB_NAME     = "estacionamento"
$env:DB_USER     = "postgres"
$env:DB_PASSWORD = "postgres"

mvn package -DskipTests
java -jar target\estacionamento.jar
```

A API estará disponível em `http://localhost:8080`.

---

### 3. Frontend

O frontend usa URLs relativas (`/api/...`), então precisa de um servidor que faça proxy das chamadas para o backend. Use o Nginx com o arquivo de configuração já incluso.

**Mac**
```bash
# Edite nginx.conf e troque "backend:8080" por "127.0.0.1:8080"
sed -i '' 's/backend:8080/127.0.0.1:8080/' frontend/nginx.conf

nginx -p "$PWD/frontend" -c "$PWD/frontend/nginx.conf"
```

**Windows**

Edite `frontend\nginx.conf` e troque `backend:8080` por `127.0.0.1:8080`, depois:
```cmd
cd frontend
nginx -p . -c nginx.conf
```

O frontend estará disponível em `http://localhost:3000`.

Para parar o Nginx:
```bash
# Mac
nginx -s stop

# Windows
nginx -s stop
```

> **Sem Nginx:** abra `frontend/index.html` no navegador e edite a primeira linha de
> `frontend/js/api.js`, adicionando `const BASE = 'http://localhost:8080'` e
> prefixando todas as chamadas com `BASE`. O backend já aceita requisições
> cross-origin (`Access-Control-Allow-Origin: *`).

---

## API REST

| Método | Endpoint                        | Descrição               |
|--------|---------------------------------|-------------------------|
| GET    | /api/dashboard                  | Indicadores gerais      |
| GET    | /api/clientes                   | Listar clientes         |
| GET    | /api/clientes/{id}              | Buscar cliente          |
| POST   | /api/clientes                   | Cadastrar cliente       |
| PUT    | /api/clientes/{id}              | Atualizar cliente       |
| DELETE | /api/clientes/{id}              | Excluir cliente         |
| GET    | /api/veiculos                   | Listar veículos         |
| POST   | /api/veiculos                   | Cadastrar veículo       |
| PUT    | /api/veiculos/{id}              | Atualizar veículo       |
| DELETE | /api/veiculos/{id}              | Excluir veículo         |
| GET    | /api/vagas                      | Listar vagas            |
| GET    | /api/vagas?status=LIVRE         | Listar vagas livres     |
| POST   | /api/vagas                      | Cadastrar vaga          |
| PUT    | /api/vagas/{id}                 | Atualizar vaga          |
| DELETE | /api/vagas/{id}                 | Excluir vaga            |
| POST   | /api/permanencias/entrada       | Registrar entrada       |
| PUT    | /api/permanencias/{id}/saida    | Registrar saída         |
| GET    | /api/permanencias               | Listar permanências     |
| GET    | /api/permanencias?status=ABERTO | Listar abertas          |

---

## Regras de negócio

- Tarifa: **R$ 5,00/hora** — mínimo 1 hora, frações arredondadas para cima
- Entrada bloqueada se o veículo já tiver uma permanência aberta
- Entrada bloqueada se a vaga estiver ocupada
- Transações JDBC garantem integridade nas operações de entrada/saída
- `SELECT FOR UPDATE` evita condições de corrida em requisições simultâneas

---

## Logs do backend

```bash
docker compose logs -f backend
```
