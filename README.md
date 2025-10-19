# aDocaFreelancer — Frontend

Este é um scaffold Next.js + TypeScript + Tailwind para o frontend do aDocaFreelancer.

## Setup rápido

1. Copie `.env.local.example` para `.env.local` e atualize `NEXT_PUBLIC_API_URL`.
2. Instale dependências:
   ```
   npm install
   ```
3. Rode em desenvolvimento:
   ```
   npm run dev
   ```

## Rotas esperadas do backend (exemplo)
- POST /auth/login { email, password } -> { token }
- GET /freelancers -> [{ id, name, title, avatar, bio }]
- GET /freelancers/:id -> { id, name, title, avatar, bio, skills }
- GET /jobs -> [{ id, title, description, price }]
