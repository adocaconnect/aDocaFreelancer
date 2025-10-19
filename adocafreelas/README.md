```markdown
# aDocaFreelancer — Checklist final para Lançamento

O backend está pronto para testes finais e lançamento com os recursos implementados:
- NestJS API com validação (class-validator) e DTOs
- JWT access + refresh tokens persistidos e rotacionáveis
- Roles (CLIENT, FREELANCER, ADMIN) e RolesGuard
- Payments: adapter Mercado Pago (createPreference, getPayment, refund), PaymentsService orquestrando depósitos/release/refund
- BullMQ worker (payout.processor) para processar payouts assincronamente
- Prisma schema com modelos essenciais (User, Profile, Project, Proposal, Contract, Transaction, RefreshToken etc.)
- Swagger em /api/docs

Antes de lançar, verifique e providencie as integrações e chaves abaixo (obrigatórias / recomendadas):

Chaves e envs obrigatórias (verifique .env):
- DATABASE_URL (Postgres)
- REDIS_URL (Redis, para BullMQ)
- JWT_ACCESS_TOKEN_SECRET
- JWT_REFRESH_TOKEN_SECRET
- MERCADOPAGO_PUBLIC_KEY
- MERCADOPAGO_ACCESS_TOKEN
- MERCADOPAGO_CLIENT_ID
- MERCADOPAGO_CLIENT_SECRET
- MERCADOPAGO_SANDBOX=true|false
- FRONTEND_URL (URL pública do frontend — para redirect/back_urls)
- BACKEND_URL (URL pública do backend — para webhooks)

Integrações/recursos ainda a configurar (recomendado antes do lançamento):
- Webhook público do Mercado Pago configurado (apontar para: <BACKEND_URL>/webhooks/mercadopago) — use ngrok em dev
- Conta Mercado Pago com permissões e configuração de payouts (se quiser payout automático)
- Implementação de payout real (agora o worker simula payout; precisa integrar com API de payouts do provedor)
- Verificação de assinatura/segurança dos webhooks Mercado Pago (implementar validação conforme docs)
- Provedor de e-mail (para verificação de email, notificações) — ex: SendGrid, SES
- Armazenamento de arquivos (S3, GCS) para attachments/portfolio
- HTTPS, domínio e certificados (NGINX / Load Balancer) em produção
- Políticas de rate limiting e WAF para segurança
- Logs/monitoring (Sentry, Prometheus, Grafana) e alertas
- Backups periódicos do Postgres
- Avaliação de conformidade PCI (se necessário) e revisão de segurança para pagamentos

Comandos essenciais (resumo):
- Instalar deps backend: cd apps/backend && npm ci
- Prisma generate: npx prisma generate --schema=../../prisma/schema.prisma
- Prisma migrate: npx prisma migrate dev --name init --schema=../../prisma/schema.prisma
- Seed: npm run seed
- Build backend: npm run build
- Start backend: npm run start
- Start worker: npm run start:worker (ou npm run dev:worker em dev)
- Frontend: cd apps/frontend && npm ci && npm run dev

Se quiser, eu:
- Integro o worker para usar Payouts reais do Mercado Pago (preciso das credenciais de payout ou docs da conta),
- Adiciono verificação de assinatura dos webhooks (baseada em cabeçalhos do Mercado Pago) — recomendo quando for para produção,
- Faço revisão de segurança e checklist de lançamento mais aprofundado.
