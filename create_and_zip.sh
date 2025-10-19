#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="adocafreelancer-ready"
echo "Criando estrutura em ./${ROOT_DIR} ..."

rm -rf "${ROOT_DIR}"
mkdir -p "${ROOT_DIR}"

# helper to write files
write() {
  local path="$1"; shift
  mkdir -p "$(dirname "${ROOT_DIR}/${path}")"
  cat > "${ROOT_DIR}/${path}" <<'EOF'
'"$@"
EOF
}

# Create directories
mkdir -p "${ROOT_DIR}/apps/backend/src/prisma"
mkdir -p "${ROOT_DIR}/apps/backend/src/auth/dto"
mkdir -p "${ROOT_DIR}/apps/backend/src/services/payments"
mkdir -p "${ROOT_DIR}/apps/backend/src/services/payments"
mkdir -p "${ROOT_DIR}/apps/backend/src/prisma"
mkdir -p "${ROOT_DIR}/apps/backend/src/jobs"
mkdir -p "${ROOT_DIR}/apps/backend/src/contracts"
mkdir -p "${ROOT_DIR}/apps/backend/src/webhooks"
mkdir -p "${ROOT_DIR}/apps/backend/src/admin"
mkdir -p "${ROOT_DIR}/apps/backend/src/users"
mkdir -p "${ROOT_DIR}/apps/backend/src/projects"
mkdir -p "${ROOT_DIR}/apps/backend/src/proposals"
mkdir -p "${ROOT_DIR}/apps/backend/src/conversations"
mkdir -p "${ROOT_DIR}/apps/frontend"
mkdir -p "${ROOT_DIR}/docker"
mkdir -p "${ROOT_DIR}/.github/workflows"
mkdir -p "${ROOT_DIR}/prisma"
mkdir -p "${ROOT_DIR}/scripts"

echo "Criando arquivos..."

# README.md
cat > "${ROOT_DIR}/README.md" <<'EOF'
# aDocaFreelancer

Monorepo para marketplace de freelancers com escrow via Mercado Pago e FEE fixa 7%.

Estrutura:
- /apps/backend (NestJS + TypeScript)
- /apps/frontend (Next.js + TypeScript + Tailwind) — scaffold
- /prisma (schema.prisma + migrations)
- /scripts (seed.ts)
- /docker (Dockerfiles)
- .github/workflows/ci.yml

Variáveis de ambiente obrigatórias (veja .env.example)

Scripts principais (no root e em apps/*):
- dev
- build
- start
- migrate
- seed
- test

Escrow: taxa fixa da plataforma = 7% (aplicada em contracts por padrão).

Documentação do backend em /api/docs (Swagger).
EOF

# .env.example
cat > "${ROOT_DIR}/.env.example" <<'EOF'
# MERCADO PAGO
MERCADOPAGO_PUBLIC_KEY=
MERCADOPAGO_ACCESS_TOKEN=
MERCADOPAGO_CLIENT_ID=
MERCADOPAGO_CLIENT_SECRET=
MERCADOPAGO_SANDBOX=true

# APP / DB
DATABASE_URL=postgresql://user:pass@postgres:5432/appdb
REDIS_URL=redis://redis:6379
JWT_ACCESS_TOKEN_SECRET=change_me
JWT_REFRESH_TOKEN_SECRET=change_me_too
NODE_ENV=development
FRONTEND_URL=http://localhost:3000
BACKEND_URL=http://localhost:4000
REFRESH_TOKEN_DAYS=30
JWT_ACCESS_TTL=15m
EOF

# docker-compose.yml
cat > "${ROOT_DIR}/docker-compose.yml" <<'EOF'
version: '3.8'
services:
  postgres:
    image: postgres:15
    environment:
      POSTGRES_DB: appdb
      POSTGRES_USER: user
      POSTGRES_PASSWORD: pass
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data

  redis:
    image: redis:7
    ports:
      - "6379:6379"
    volumes:
      - redis_data:/data

  backend:
    build:
      context: .
      dockerfile: docker/Dockerfile.backend
    env_file:
      - .env
    volumes:
      - ./apps/backend:/app
    ports:
      - "4000:4000"
    depends_on:
      - postgres
      - redis

  frontend:
    build:
      context: .
      dockerfile: docker/Dockerfile.frontend
    env_file:
      - .env
    volumes:
      - ./apps/frontend:/app
    ports:
      - "3000:3000"
    depends_on:
      - backend

volumes:
  postgres_data:
  redis_data:
EOF

# docker/Dockerfile.backend
cat > "${ROOT_DIR}/docker/Dockerfile.backend" <<'EOF'
FROM node:20-alpine
WORKDIR /app
COPY apps/backend/package*.json ./
RUN npm ci --silent
COPY apps/backend ./
RUN npm run build
EXPOSE 4000
CMD ["node", "dist/main.js"]
EOF

# docker/Dockerfile.frontend
cat > "${ROOT_DIR}/docker/Dockerfile.frontend" <<'EOF'
FROM node:20-alpine
WORKDIR /app
COPY apps/frontend/package*.json ./
RUN npm ci --silent
COPY apps/frontend ./
RUN npm run build || true
EXPOSE 3000
CMD ["npm", "run", "start"]
EOF

# .github/workflows/ci.yml
cat > "${ROOT_DIR}/.github/workflows/ci.yml" <<'EOF'
name: CI

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

jobs:
  build-and-test:
    runs-on: ubuntu-latest
    services:
      postgres:
        image: postgres:15
        env:
          POSTGRES_DB: appdb
          POSTGRES_USER: user
          POSTGRES_PASSWORD: pass
        ports:
          - 5432:5432
      redis:
        image: redis:7
        ports:
          - 6379:6379

    steps:
      - uses: actions/checkout@v4
      - name: Use Node.js 20
        uses: actions/setup-node@v4
        with:
          node-version: 20

      - name: Install backend deps
        working-directory: apps/backend
        run: npm ci

      - name: Run prisma migrations
        working-directory: apps/backend
        env:
          DATABASE_URL: postgresql://user:pass@localhost:5432/appdb
        run: npx prisma migrate deploy --schema=../../prisma/schema.prisma

      - name: Build backend
        working-directory: apps/backend
        run: npm run build

      - name: Run backend tests
        working-directory: apps/backend
        run: npm run test --if-present
EOF

# prisma/schema.prisma
cat > "${ROOT_DIR}/prisma/schema.prisma" <<'EOF'
generator client {
  provider = "prisma-client-js"
}

datasource db {
  provider = "postgresql"
  url      = env("DATABASE_URL")
}

model User {
  id           String    @id @default(uuid())
  name         String
  email        String    @unique
  passwordHash String
  role         Role
  createdAt    DateTime  @default(now())
  profile      Profile?
  proposals    Proposal[] @relation("UserProposals")
  contractsAsClient Contract[] @relation("ClientContracts")
  contractsAsFreelancer Contract[] @relation("FreelancerContracts")
  messagesSent Message[] @relation("MessageSender")
  uploads      File[] @relation("Uploads")
  reviewsLeft  Review[] @relation("Reviewer")
  reviewsRight Review[] @relation("Reviewee")
  refreshTokens RefreshToken[]
}

model RefreshToken {
  id         String   @id @default(uuid())
  tokenHash  String
  userId     String
  expiresAt  DateTime
  revoked    Boolean  @default(false)
  createdAt  DateTime @default(now())

  user User @relation(fields: [userId], references: [id])

  @@index([userId])
}

model Profile {
  id             String   @id @default(uuid())
  userId         String   @unique
  bio            String?
  skills         String[]
  portfolio      Json?
  hourlyRate     Float?
  ratingAvg      Float?   @default(0)
  completedJobs  Int      @default(0)
  user           User     @relation(fields: [userId], references: [id])
}

model Project {
  id          String     @id @default(uuid())
  clientId    String
  title       String
  description String
  category    String
  budgetMin   Float
  budgetMax   Float
  status      ProjectStatus
  deadline    DateTime?
  attachments Json?
  createdAt   DateTime   @default(now())
  client      User       @relation(fields: [clientId], references: [id])
  proposals   Proposal[]
  contract    Contract?
}

model Proposal {
  id           String     @id @default(uuid())
  projectId    String
  freelancerId String
  coverLetter  String
  price        Float
  days         Int
  status       ProposalStatus
  createdAt    DateTime   @default(now())
  project      Project    @relation(fields: [projectId], references: [id])
  freelancer   User       @relation("UserProposals", fields: [freelancerId], references: [id])
  contract     Contract?
}

model Contract {
  id                    String          @id @default(uuid())
  projectId             String
  proposalId            String
  clientId              String
  freelancerId          String
  amount                Float
  appliedPlatformFeePct Float           @default(7.0)
  platformFeeAmount     Float
  providerFeeAmount     Float
  netAmount             Float
  escrowStatus          EscrowStatus
  createdAt             DateTime        @default(now())
  project               Project         @relation(fields: [projectId], references: [id])
  proposal              Proposal        @relation(fields: [proposalId], references: [id])
  client                User            @relation("ClientContracts", fields: [clientId], references: [id])
  freelancer            User            @relation("FreelancerContracts", fields: [freelancerId], references: [id])
  transactions          Transaction[]
  review                Review?
}

model Transaction {
  id                String        @id @default(uuid())
  contractId        String
  type              TransactionType
  amount            Float
  platformFeeAmount Float
  providerFeeAmount Float
  netAmount         Float
  providerTxId      String?
  createdAt         DateTime     @default(now())
  contract          Contract     @relation(fields: [contractId], references: [id])
}

model Conversation {
  id           String      @id @default(uuid())
  participants String[]
  messages     Message[]
}

model Message {
  id             String      @id @default(uuid())
  conversationId String
  senderId       String
  content        String
  createdAt      DateTime    @default(now())
  conversation   Conversation @relation(fields: [conversationId], references: [id])
  sender         User        @relation("MessageSender", fields: [senderId], references: [id])
}

model File {
  id         String   @id @default(uuid())
  url        String
  uploaderId String
  uploadedAt DateTime @default(now())
  uploader   User     @relation("Uploads", fields: [uploaderId], references: [id])
}

model Review {
  id           String   @id @default(uuid())
  reviewerId   String
  revieweeId   String
  contractId   String
  rating       Int
  comment      String
  createdAt    DateTime @default(now())
  reviewer     User     @relation("Reviewer", fields: [reviewerId], references: [id])
  reviewee     User     @relation("Reviewee", fields: [revieweeId], references: [id])
  contract     Contract @relation(fields: [contractId], references: [id])
}

model AdminSettings {
  id                      String @id @default(uuid())
  mercadoPagoPublicKey     String?
  mercadoPagoAccessToken   String?
  mercadoPagoClientId      String?
  mercadoPagoClientSecret  String?
  mercadoPagoSandbox       Boolean @default(true)
  platformFeePct           Float   @default(7.0)
  feePayerConfig           Json?
  updatedAt                DateTime @updatedAt
}

enum Role {
  CLIENT
  FREELANCER
  ADMIN
}

enum ProjectStatus {
  DRAFT
  OPEN
  CLOSED
}

enum ProposalStatus {
  PENDING
  ACCEPTED
  REJECTED
}

enum EscrowStatus {
  CREATED
  HELD
  RELEASED
  REFUNDED
}

enum TransactionType {
  DEPOSIT
  RELEASE
  REFUND
  FEE
}
EOF

# scripts/seed.ts
cat > "${ROOT_DIR}/scripts/seed.ts" <<'EOF'
import { PrismaClient } from '@prisma/client';
import * as bcrypt from 'bcryptjs';

const prisma = new PrismaClient();

async function main() {
  const passwordHash = await bcrypt.hash('adminpass', 10);

  const admin = await prisma.user.upsert({
    where: { email: 'admin@adocafreelancer.local' },
    update: {},
    create: {
      name: 'Admin',
      email: 'admin@adocafreelancer.local',
      passwordHash,
      role: 'ADMIN',
      profile: {
        create: {
          bio: 'Platform administrator',
          skills: [],
        },
      },
    },
  });

  const settings = await prisma.adminSettings.upsert({
    where: { id: admin.id },
    update: {},
    create: {
      mercadoPagoSandbox: true,
      platformFeePct: 7.0,
    },
  });

  console.log({ admin: admin.email, settingsId: settings.id });
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
EOF

# apps/backend/package.json
cat > "${ROOT_DIR}/apps/backend/package.json" <<'EOF'
{
  "name": "adocafreelancer-backend",
  "version": "0.1.0",
  "private": true,
  "scripts": {
    "dev": "nest start --watch",
    "dev:worker": "ts-node -r tsconfig-paths/register src/jobs/payout.processor.ts",
    "build": "nest build",
    "start": "node dist/main.js",
    "start:worker": "node dist/src/jobs/payout.processor.js",
    "migrate": "prisma migrate dev --schema=../../prisma/schema.prisma",
    "seed": "ts-node -r tsconfig-paths/register ../../scripts/seed.ts",
    "test": "jest"
  },
  "dependencies": {
    "@nestjs/common": "^10.0.0",
    "@nestjs/core": "^10.0.0",
    "@nestjs/jwt": "^10.0.0",
    "@nestjs/passport": "^10.0.0",
    "@nestjs/platform-express": "^10.0.0",
    "@nestjs/swagger": "^6.1.2",
    "class-transformer": "^0.5.1",
    "class-validator": "^0.14.0",
    "bcryptjs": "^2.4.3",
    "passport": "^0.6.0",
    "passport-jwt": "^4.0.1",
    "@prisma/client": "^5.0.0",
    "prisma": "^5.0.0",
    "axios": "^1.4.0",
    "bullmq": "^2.0.0",
    "ioredis": "^5.3.2",
    "reflect-metadata": "^0.1.13"
  },
  "devDependencies": {
    "@nestjs/cli": "^10.0.0",
    "@nestjs/schematics": "^10.0.0",
    "@nestjs/testing": "^10.0.0",
    "@types/express": "^4.17.17",
    "@types/jest": "^29.5.2",
    "@types/node": "^20.0.0",
    "jest": "^29.5.0",
    "ts-jest": "^29.1.1",
    "ts-node": "^10.9.1",
    "typescript": "^5.2.0"
  }
}
EOF

# apps/backend/tsconfig.json
cat > "${ROOT_DIR}/apps/backend/tsconfig.json" <<'EOF'
{
  "compilerOptions": {
    "module": "CommonJS",
    "declaration": true,
    "removeComments": true,
    "emitDecoratorMetadata": true,
    "experimentalDecorators": true,
    "allowSyntheticDefaultImports": true,
    "target": "ES2020",
    "sourceMap": true,
    "outDir": "dist",
    "baseUrl": "./",
    "incremental": true,
    "skipLibCheck": true,
    "paths": {}
  },
  "exclude": ["node_modules", "dist"]
}
EOF

# apps/backend/src/main.ts
cat > "${ROOT_DIR}/apps/backend/src/main.ts" <<'EOF'
import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';
import { setupSwagger } from './swagger';
import * as helmet from 'helmet';
import * as cookieParser from 'cookie-parser';

async function bootstrap() {
  const app = await NestFactory.create(AppModule);
  app.use(helmet());
  app.enableCors({
    origin: process.env.FRONTEND_URL || 'http://localhost:3000',
    credentials: true,
  });
  app.use(cookieParser());
  setupSwagger(app);
  await app.listen(process.env.PORT ? +process.env.PORT : 4000);
  console.log(`Backend running on ${await app.getUrl()}`);
}
bootstrap();
EOF

# apps/backend/src/app.module.ts
cat > "${ROOT_DIR}/apps/backend/src/app.module.ts" <<'EOF'
import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { PrismaModule } from './prisma/prisma.module';
import { AuthModule } from './auth/auth.module';
import { UsersModule } from './users/users.module';
import { ProjectsModule } from './projects/projects.module';
import { ProposalsModule } from './proposals/proposals.module';
import { ContractsModule } from './contracts/contracts.module';
import { WebhooksModule } from './webhooks/webhooks.module';
import { AdminModule } from './admin/admin.module';
import { ConversationsModule } from './conversations/conversations.module';
import { PaymentsModule } from './services/payments/payments.module';

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true }),
    PrismaModule,
    PaymentsModule,
    AuthModule,
    UsersModule,
    ProjectsModule,
    ProposalsModule,
    ContractsModule,
    WebhooksModule,
    AdminModule,
    ConversationsModule,
  ],
  controllers: [],
  providers: [],
})
export class AppModule {}
EOF

# apps/backend/src/swagger.ts
cat > "${ROOT_DIR}/apps/backend/src/swagger.ts" <<'EOF'
import { INestApplication } from '@nestjs/common';
import { DocumentBuilder, SwaggerModule } from '@nestjs/swagger';

export function setupSwagger(app: INestApplication) {
  const config = new DocumentBuilder()
    .setTitle('aDocaFreelancer API')
    .setDescription('API para marketplace de freelancers com escrow Mercado Pago')
    .setVersion('1.0')
    .addBearerAuth()
    .build();
  const document = SwaggerModule.createDocument(app, config);
  SwaggerModule.setup('api/docs', app, document);
}
EOF

# apps/backend/src/prisma/prisma.module.ts
cat > "${ROOT_DIR}/apps/backend/src/prisma/prisma.module.ts" <<'EOF'
import { Module } from '@nestjs/common';
import { PrismaService } from './prisma.service';

@Module({
  providers: [PrismaService],
  exports: [PrismaService],
})
export class PrismaModule {}
EOF

# apps/backend/src/prisma/prisma.service.ts
cat > "${ROOT_DIR}/apps/backend/src/prisma/prisma.service.ts" <<'EOF'
import { Injectable, OnModuleInit, OnModuleDestroy } from '@nestjs/common';
import { PrismaClient } from '@prisma/client';

@Injectable()
export class PrismaService extends PrismaClient implements OnModuleInit, OnModuleDestroy {
  async onModuleInit() {
    await this.$connect();
  }
  async onModuleDestroy() {
    await this.$disconnect();
  }
}
EOF

# services/payments/calculateFees.ts
cat > "${ROOT_DIR}/apps/backend/src/services/payments/calculateFees.ts" <<'EOF'
export function calculateFees(amount: number, platformFeePct = 7.0, providerFeePct = 0, providerFeeFixed = 0) {
  const platformFeeAmount = +(amount * (platformFeePct / 100)).toFixed(2);
  const providerFeeAmount = +((amount * (providerFeePct / 100)) + providerFeeFixed).toFixed(2);
  const netAmount = +(amount - platformFeeAmount - providerFeeAmount).toFixed(2);
  return { platformFeePct, platformFeeAmount, providerFeeAmount, netAmount };
}
EOF

# services/payments/mercadopago.adapter.ts
cat > "${ROOT_DIR}/apps/backend/src/services/payments/mercadopago.adapter.ts" <<'EOF'
import axios from 'axios';

/**
 * MercadoPagoAdapter
 *
 * - createPreference(contractId, amount, description, returnUrl)
 * - getPayment(paymentId) -> fetch payment details
 * - verifyNotification(payload) -> normalize webhook payload to { status, providerFee, providerTxId, raw }
 * - refund(txId, amount)
 *
 * Note: This is an integration helper. In production validate receipts/signatures
 * using Mercado Pago docs and handle retries/errors thoroughly.
 */
export class MercadoPagoAdapter {
  private accessToken: string;
  private sandbox: boolean;

  constructor(accessToken: string, sandbox = true) {
    this.accessToken = accessToken;
    this.sandbox = sandbox;
  }

  private get apiBase() {
    return 'https://api.mercadopago.com';
  }

  async createPreference(contractId: string, amount: number, description: string, returnUrl: string) {
    const payload: any = {
      items: [
        {
          title: `Contract ${contractId}`,
          description,
          quantity: 1,
          unit_price: amount,
        },
      ],
      external_reference: contractId,
      back_urls: {
        success: returnUrl,
        failure: returnUrl,
        pending: returnUrl,
      },
      binary_mode: true,
    };

    const res = await axios.post(`${this.apiBase}/checkout/preferences`, payload, {
      headers: { Authorization: `Bearer ${this.accessToken}` },
    });

    return res.data;
  }

  // Fetch payment details by payment id (v1/payments/{id})
  async getPayment(paymentId: string) {
    if (!paymentId) throw new Error('paymentId required');
    const res = await axios.get(`${this.apiBase}/v1/payments/${paymentId}`, {
      headers: { Authorization: `Bearer ${this.accessToken}` },
    });
    return res.data;
  }

  // Given incoming webhook payload (topic/resource or payment data) try to normalize
  // into standard object with providerFee and providerTxId.
  async verifyNotification(payload: any) {
    try {
      const paymentId = payload?.data?.id || payload?.id || payload?.resource?.id || payload?.payment_id;
      if (paymentId) {
        const payment = await this.getPayment(paymentId);
        const providerFee = (payment.transaction_details?.total_paid_amount || 0) - (payment.transaction_details?.net_received_amount || 0);
        return {
          status: payment.status || 'unknown',
          providerFee: providerFee || 0,
          providerTxId: String(payment.id || paymentId),
          externalReference: payment.external_reference || null,
          raw: payment,
        };
      }

      return {
        status: payload?.status || payload?.topic || 'unknown',
        providerFee: payload?.fee_amount || 0,
        providerTxId: payload?.id || null,
        externalReference: payload?.external_reference || payload?.preference?.external_reference || null,
        raw: payload,
      };
    } catch (err: any) {
      return { status: 'error', providerFee: 0, providerTxId: null, raw: payload, error: err?.message };
    }
  }

  async refund(txId: string, amount?: number) {
    if (!txId) throw new Error('txId required for refund');
    const body = amount ? { amount } : {};
    const res = await axios.post(`${this.apiBase}/v1/payments/${txId}/refunds`, body, {
      headers: { Authorization: `Bearer ${this.accessToken}` },
    });
    return res.data;
  }
}
EOF

# services/payments/payments.service.ts
cat > "${ROOT_DIR}/apps/backend/src/services/payments/payments.service.ts" <<'EOF'
import { Injectable, Logger } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { MercadoPagoAdapter } from './mercadopago.adapter';
import { calculateFees } from './calculateFees';
import { Queue } from 'bullmq';
import IORedis from 'ioredis';
import { v4 as uuidv4 } from 'uuid';

const REDIS_URL = process.env.REDIS_URL || 'redis://localhost:6379';

@Injectable()
export class PaymentsService {
  private mpAdapter: MercadoPagoAdapter;
  private payoutQueue: Queue;
  private logger = new Logger(PaymentsService.name);

  constructor(private prisma: PrismaService) {
    this.mpAdapter = new MercadoPagoAdapter(process.env.MERCADOPAGO_ACCESS_TOKEN || '', process.env.MERCADOPAGO_SANDBOX === 'true');

    // setup a simple BullMQ queue for payouts
    this.payoutQueue = new Queue('payouts', { connection: new IORedis(REDIS_URL) });
  }

  async createDepositPreference(contractId: string, returnUrl: string) {
    const contract = await this.prisma.contract.findUnique({ where: { id: contractId } });
    if (!contract) throw new Error('Contract not found');

    const pref = await this.mpAdapter.createPreference(contract.id, contract.amount, `Escrow for contract ${contract.id}`, returnUrl || process.env.FRONTEND_URL || 'http://localhost:3000');
    return pref;
  }

  async handleProviderNotification(payload: any) {
    const verified = await this.mpAdapter.verifyNotification(payload);
    this.logger.debug({ verified });

    const externalRef = verified.externalReference || payload?.external_reference || payload?.preference?.external_reference;
    if (!externalRef) {
      this.logger.warn('No external_reference found in notification');
      return { ok: false, reason: 'no_external_reference', verified };
    }

    const contract = await this.prisma.contract.findUnique({ where: { id: externalRef } });
    if (!contract) {
      this.logger.warn('Contract not found for external reference', externalRef);
      return { ok: false, reason: 'contract_not_found', verified };
    }

    const exists = await this.prisma.transaction.findFirst({ where: { providerTxId: verified.providerTxId } });
    if (exists) {
      this.logger.debug('Transaction already exists for providerTxId', verified.providerTxId);
      return { ok: true, id: exists.id };
    }

    const depositTx = await this.prisma.transaction.create({
      data: {
        contractId: contract.id,
        type: 'DEPOSIT',
        amount: contract.amount,
        platformFeeAmount: 0,
        providerFeeAmount: verified.providerFee || 0,
        netAmount: 0,
        providerTxId: verified.providerTxId,
      },
    });

    await this.prisma.contract.update({
      where: { id: contract.id },
      data: {
        escrowStatus: 'HELD',
        providerFeeAmount: verified.providerFee || 0,
      },
    });

    return { ok: true, depositTxId: depositTx.id };
  }

  async releaseToFreelancer(contractId: string) {
    const contract = await this.prisma.contract.findUnique({ where: { id: contractId } });
    if (!contract) throw new Error('Contract not found');

    if (contract.escrowStatus !== 'HELD') {
      throw new Error('Contract is not in HELD state');
    }

    const providerFeeAmount = contract.providerFeeAmount ?? 0;
    const fees = calculateFees(contract.amount, contract.appliedPlatformFeePct, 0, providerFeeAmount);

    const releaseTx = await this.prisma.transaction.create({
      data: {
        contractId: contract.id,
        type: 'RELEASE',
        amount: contract.amount,
        platformFeeAmount: fees.platformFeeAmount,
        providerFeeAmount: fees.providerFeeAmount,
        netAmount: fees.netAmount,
        providerTxId: null,
      },
    });

    await this.prisma.contract.update({
      where: { id: contract.id },
      data: {
        escrowStatus: 'RELEASED',
        platformFeeAmount: fees.platformFeeAmount,
        netAmount: fees.netAmount,
      },
    });

    await this.payoutQueue.add('payout', {
      contractId: contract.id,
      transactionId: releaseTx.id,
      amount: fees.netAmount,
      freelancerId: contract.freelancerId,
    }, { jobId: `payout-${releaseTx.id}` });

    return { ok: true, releaseTxId: releaseTx.id, fees };
  }

  async refund(contractId: string, providerTxId: string) {
    const contract = await this.prisma.contract.findUnique({ where: { id: contractId } });
    if (!contract) throw new Error('Contract not found');

    if (!providerTxId) throw new Error('providerTxId required to refund');

    const res = await this.mpAdapter.refund(providerTxId, contract.amount);

    const refundTx = await this.prisma.transaction.create({
      data: {
        contractId: contract.id,
        type: 'REFUND',
        amount: contract.amount,
        platformFeeAmount: 0,
        providerFeeAmount: contract.providerFeeAmount || 0,
        netAmount: 0,
        providerTxId: providerTxId,
      },
    });

    await this.prisma.contract.update({
      where: { id: contract.id },
      data: { escrowStatus: 'REFUNDED' },
    });

    return { ok: true, refundTxId: refundTx.id, providerResponse: res };
  }
}
EOF

# services/payments/payments.module.ts
cat > "${ROOT_DIR}/apps/backend/src/services/payments/payments.module.ts" <<'EOF'
import { Module } from '@nestjs/common';
import { PrismaModule } from '../../prisma/prisma.module';
import { PaymentsService } from './payments.service';

@Module({
  imports: [PrismaModule],
  providers: [PaymentsService],
  exports: [PaymentsService],
})
export class PaymentsModule {}
EOF

# jobs/payout.processor.ts
cat > "${ROOT_DIR}/apps/backend/src/jobs/payout.processor.ts" <<'EOF'
import { Worker } from 'bullmq';
import IORedis from 'ioredis';
import { PrismaClient } from '@prisma/client';
import { v4 as uuidv4 } from 'uuid';

const REDIS_URL = process.env.REDIS_URL || 'redis://localhost:6379';
const connection = new IORedis(REDIS_URL);
const prisma = new PrismaClient();

const worker = new Worker(
  'payouts',
  async (job) => {
    const { contractId, transactionId, amount, freelancerId } = job.data as any;
    const providerPayoutId = `payout_${uuidv4()}`;

    await prisma.transaction.update({
      where: { id: transactionId },
      data: {
        providerTxId: providerPayoutId,
      },
    });

    await prisma.contract.update({
      where: { id: contractId },
      data: {
        escrowStatus: 'RELEASED',
      },
    });

    return { providerPayoutId, ok: true };
  },
  { connection },
);

worker.on('completed', (job) => {
  console.log(`Payout job ${job.id} completed`);
});

worker.on('failed', (job, err) => {
  console.error(`Payout job ${job?.id} failed:`, err);
});

export default worker;
EOF

# contracts/contracts.service.ts
cat > "${ROOT_DIR}/apps/backend/src/contracts/contracts.service.ts" <<'EOF'
import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { PaymentsService } from '../services/payments/payments.service';

@Injectable()
export class ContractsService {
  constructor(private prisma: PrismaService, private payments: PaymentsService) {}

  async createFromProposal(projectId: string, proposalId: string) {
    const proposal = await this.prisma.proposal.findUnique({ where: { id: proposalId } });
    if (!proposal) throw new Error('Proposal not found');

    const project = await this.prisma.project.findUnique({ where: { id: projectId } });
    if (!project) throw new Error('Project not found');

    const contract = await this.prisma.contract.create({
      data: {
        projectId,
        proposalId,
        clientId: project.clientId,
        freelancerId: proposal.freelancerId,
        amount: proposal.price,
        appliedPlatformFeePct: 7.0,
        platformFeeAmount: 0,
        providerFeeAmount: 0,
        netAmount: 0,
        escrowStatus: 'CREATED',
      },
    });

    return contract;
  }

  async createDepositPreference(contractId: string, returnUrl: string) {
    return this.payments.createDepositPreference(contractId, returnUrl);
  }

  async release(contractId: string) {
    return this.payments.releaseToFreelancer(contractId);
  }

  async refund(contractId: string, providerTxId: string) {
    return this.payments.refund(contractId, providerTxId);
  }
}
EOF

# contracts/contracts.controller.ts
cat > "${ROOT_DIR}/apps/backend/src/contracts/contracts.controller.ts" <<'EOF'
import { Body, Controller, Param, Post, UseGuards } from '@nestjs/common';
import { ContractsService } from './contracts.service';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';

@Controller('contracts')
export class ContractsController {
  constructor(private service: ContractsService) {}

  @UseGuards(JwtAuthGuard)
  @Post(':id/escrow/deposit')
  async deposit(@Param('id') id: string, @Body() body: { returnUrl: string }) {
    return this.service.createDepositPreference(id, body?.returnUrl);
  }

  @UseGuards(JwtAuthGuard)
  @Post(':id/escrow/release')
  async release(@Param('id') id: string) {
    return this.service.release(id);
  }

  @UseGuards(JwtAuthGuard)
  @Post(':id/escrow/refund')
  async refund(@Param('id') id: string, @Body() body: { providerTxId: string }) {
    return this.service.refund(id, body.providerTxId);
  }
}
EOF

# webhooks module/controller
cat > "${ROOT_DIR}/apps/backend/src/webhooks/webhooks.controller.ts" <<'EOF'
import { Body, Controller, Post, Req } from '@nestjs/common';
import { PaymentsService } from '../services/payments/payments.service';

@Controller('webhooks')
export class WebhooksController {
  constructor(private payments: PaymentsService) {}

  @Post('mercadopago')
  async mercadopago(@Req() req: any, @Body() body: any) {
    const res = await this.payments.handleProviderNotification(body);
    return res;
  }
}
EOF

cat > "${ROOT_DIR}/apps/backend/src/webhooks/webhooks.module.ts" <<'EOF'
import { Module } from '@nestjs/common';
import { PrismaModule } from '../prisma/prisma.module';
import { WebhooksController } from './webhooks.controller';
import { PaymentsModule } from '../services/payments/payments.module';

@Module({
  imports: [PrismaModule, PaymentsModule],
  controllers: [WebhooksController],
})
export class WebhooksModule {}
EOF

# auth module + files
cat > "${ROOT_DIR}/apps/backend/src/auth/dto/register.dto.ts" <<'EOF'
export class RegisterDto {
  name!: string;
  email!: string;
  password!: string;
  role!: 'CLIENT' | 'FREELANCER' | 'ADMIN';
}
EOF

cat > "${ROOT_DIR}/apps/backend/src/auth/dto/login.dto.ts" <<'EOF'
export class LoginDto {
  email!: string;
  password!: string;
}
EOF

cat > "${ROOT_DIR}/apps/backend/src/auth/dto/refresh.dto.ts" <<'EOF'
export class RefreshDto {
  refreshToken!: string;
}
EOF

cat > "${ROOT_DIR}/apps/backend/src/auth/refresh-token.service.ts" <<'EOF'
import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import * as bcrypt from 'bcryptjs';
import { randomBytes } from 'crypto';
import { v4 as uuidv4 } from 'uuid';

@Injectable()
export class RefreshTokenService {
  constructor(private prisma: PrismaService) {}

  private async hashToken(token: string) {
    return bcrypt.hash(token, 10);
  }

  private generatePlainToken() {
    return randomBytes(48).toString('hex');
  }

  async create(userId: string, expiresInDays = 30) {
    const id = uuidv4();
    const plainToken = this.generatePlainToken();
    const tokenHash = await this.hashToken(plainToken);
    const expiresAt = new Date(Date.now() + expiresInDays * 24 * 60 * 60 * 1000);
    const record = await this.prisma.refreshToken.create({
      data: { id, tokenHash, userId, expiresAt },
    });
    return `${record.id}::${plainToken}`;
  }

  async rotate(oldTokenId: string, userId: string, expiresInDays = 30) {
    await this.prisma.refreshToken.updateMany({
      where: { id: oldTokenId, userId },
      data: { revoked: true },
    });
    return this.create(userId, expiresInDays);
  }

  async revoke(tokenId: string, userId?: string) {
    const where: any = { id: tokenId };
    if (userId) where.userId = userId;
    const res = await this.prisma.refreshToken.updateMany({
      where,
      data: { revoked: true },
    });
    return res.count > 0;
  }

  async validateAndConsume(packed: string) {
    if (!packed || !packed.includes('::')) return null;
    const [id, plain] = packed.split('::');
    if (!id || !plain) return null;
    const tokenRecord = await this.prisma.refreshToken.findUnique({ where: { id } });
    if (!tokenRecord) return null;
    if (tokenRecord.revoked) return null;
    if (tokenRecord.expiresAt < new Date()) return null;
    const ok = await bcrypt.compare(plain, tokenRecord.tokenHash);
    if (!ok) return null;
    return { id: tokenRecord.id, userId: tokenRecord.userId };
  }
}
EOF

cat > "${ROOT_DIR}/apps/backend/src/auth/auth.service.ts" <<'EOF'
import { Injectable, UnauthorizedException, BadRequestException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import * as bcrypt from 'bcryptjs';
import { JwtService } from '@nestjs/jwt';
import { RefreshTokenService } from './refresh-token.service';

@Injectable()
export class AuthService {
  private accessTokenTtl = process.env.JWT_ACCESS_TTL || '15m';
  private refreshTokenDays = Number(process.env.REFRESH_TOKEN_DAYS || 30);

  constructor(
    private prisma: PrismaService,
    private jwt: JwtService,
    private refreshTokenService: RefreshTokenService,
  ) {}

  async register(data: { name: string; email: string; password: string; role: string }) {
    const existing = await this.prisma.user.findUnique({ where: { email: data.email } });
    if (existing) throw new BadRequestException('Email already in use');
    const hash = await bcrypt.hash(data.password, 10);
    const user = await this.prisma.user.create({
      data: {
        name: data.name,
        email: data.email,
        passwordHash: hash,
        role: data.role as any,
        profile: { create: { bio: '', skills: [] } },
      },
    });
    const tokens = await this.generateTokens(user.id, user.email, user.role);
    return { user: { id: user.id, email: user.email, name: user.name, role: user.role }, ...tokens };
  }

  async validateUser(email: string, password: string) {
    const user = await this.prisma.user.findUnique({ where: { email } });
    if (!user) return null;
    const ok = await bcrypt.compare(password, user.passwordHash);
    if (!ok) return null;
    return user;
  }

  async login(email: string, password: string) {
    const user = await this.validateUser(email, password);
    if (!user) throw new UnauthorizedException('Invalid credentials');
    const tokens = await this.generateTokens(user.id, user.email, user.role);
    return { user: { id: user.id, email: user.email, name: user.name, role: user.role }, ...tokens };
  }

  private signAccessToken(userId: string, email: string, role: string) {
    const payload = { sub: userId, email, role };
    return this.jwt.sign(payload, {
      secret: process.env.JWT_ACCESS_TOKEN_SECRET || 'change_me',
      expiresIn: this.accessTokenTtl,
    });
  }

  async generateTokens(userId: string, email: string, role: string) {
    const accessToken = this.signAccessToken(userId, email, role);
    const refreshToken = await this.refreshTokenService.create(userId, this.refreshTokenDays);
    return { accessToken, refreshToken, expiresIn: this.accessTokenTtl };
  }

  async refresh(refreshPacked: string) {
    const valid = await this.refreshTokenService.validateAndConsume(refreshPacked);
    if (!valid) throw new UnauthorizedException('Invalid refresh token');

    const newRefresh = await this.refreshTokenService.rotate(valid.id, valid.userId, this.refreshTokenDays);

    const user = await this.prisma.user.findUnique({ where: { id: valid.userId } });
    if (!user) throw new UnauthorizedException('User not found');

    const accessToken = this.signAccessToken(user.id, user.email, user.role);
    return { accessToken, refreshToken: newRefresh, expiresIn: this.accessTokenTtl };
  }

  async logout(refreshPacked: string) {
    const valid = await this.refreshTokenService.validateAndConsume(refreshPacked);
    if (!valid) return false;
    await this.refreshTokenService.revoke(valid.id, valid.userId);
    return true;
  }
}
EOF

cat > "${ROOT_DIR}/apps/backend/src/auth/auth.controller.ts" <<'EOF'
import { Body, Controller, Post } from '@nestjs/common';
import { AuthService } from './auth.service';
import { RegisterDto } from './dto/register.dto';
import { LoginDto } from './dto/login.dto';
import { RefreshDto } from './dto/refresh.dto';

@Controller('auth')
export class AuthController {
  constructor(private service: AuthService) {}

  @Post('register')
  async register(@Body() body: RegisterDto) {
    return this.service.register(body);
  }

  @Post('login')
  async login(@Body() body: LoginDto) {
    return this.service.login(body.email, body.password);
  }

  @Post('refresh')
  async refresh(@Body() body: RefreshDto) {
    return this.service.refresh(body.refreshToken);
  }

  @Post('logout')
  async logout(@Body() body: RefreshDto) {
    const ok = await this.service.logout(body.refreshToken);
    return { ok };
  }

  @Post('verify-email')
  async verifyEmail(@Body() body: { token: string }) {
    return { ok: true };
  }
}
EOF

cat > "${ROOT_DIR}/apps/backend/src/auth/jwt.strategy.ts" <<'EOF'
import { Injectable } from '@nestjs/common';
import { PassportStrategy } from '@nestjs/passport';
import { Strategy, ExtractJwt } from 'passport-jwt';

@Injectable()
export class JwtStrategy extends PassportStrategy(Strategy) {
  constructor() {
    super({
      jwtFromRequest: ExtractJwt.fromAuthHeaderAsBearerToken(),
      ignoreExpiration: false,
      secretOrKey: process.env.JWT_ACCESS_TOKEN_SECRET || 'change_me',
    });
  }

  async validate(payload: any) {
    return { userId: payload.sub, email: payload.email, role: payload.role };
  }
}
EOF

cat > "${ROOT_DIR}/apps/backend/src/auth/jwt-auth.guard.ts" <<'EOF'
import { Injectable } from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';

@Injectable()
export class JwtAuthGuard extends AuthGuard('jwt') {}
EOF

cat > "${ROOT_DIR}/apps/backend/src/auth/auth.module.ts" <<'EOF'
import { Module } from '@nestjs/common';
import { JwtModule } from '@nestjs/jwt';
import { AuthService } from './auth.service';
import { AuthController } from './auth.controller';
import { PrismaModule } from '../prisma/prisma.module';
import { PassportModule } from '@nestjs/passport';
import { JwtStrategy } from './jwt.strategy';
import { RefreshTokenService } from './refresh-token.service';

@Module({
  imports: [
    PrismaModule,
    PassportModule,
    JwtModule.register({
      secret: process.env.JWT_ACCESS_TOKEN_SECRET || 'change_me',
      signOptions: { expiresIn: process.env.JWT_ACCESS_TTL || '15m' },
    }),
  ],
  providers: [AuthService, JwtStrategy, RefreshTokenService],
  controllers: [AuthController],
  exports: [AuthService],
})
export class AuthModule {}
EOF

# users module/controller
cat > "${ROOT_DIR}/apps/backend/src/users/users.module.ts" <<'EOF'
import { Module } from '@nestjs/common';
import { UsersController } from './users.controller';
import { PrismaModule } from '../prisma/prisma.module';

@Module({
  imports: [PrismaModule],
  controllers: [UsersController],
})
export class UsersModule {}
EOF

cat > "${ROOT_DIR}/apps/backend/src/users/users.controller.ts" <<'EOF'
import { Body, Controller, Get, Param, Put } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

@Controller('users')
export class UsersController {
  constructor(private prisma: PrismaService) {}

  @Get(':id/profile')
  async getProfile(@Param('id') id: string) {
    return this.prisma.profile.findUnique({ where: { userId: id } });
  }

  @Put(':id/profile')
  async updateProfile(@Param('id') id: string, @Body() body: any) {
    return this.prisma.profile.update({ where: { userId: id }, data: body });
  }
}
EOF

# projects module/controller
cat > "${ROOT_DIR}/apps/backend/src/projects/projects.module.ts" <<'EOF'
import { Module } from '@nestjs/common';
import { ProjectsController } from './projects.controller';
import { PrismaModule } from '../prisma/prisma.module';

@Module({
  imports: [PrismaModule],
  controllers: [ProjectsController],
})
export class ProjectsModule {}
EOF

cat > "${ROOT_DIR}/apps/backend/src/projects/projects.controller.ts" <<'EOF'
import { Body, Controller, Get, Param, Post, Put, Query } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

@Controller('projects')
export class ProjectsController {
  constructor(private prisma: PrismaService) {}

  @Post()
  async create(@Body() body: any) {
    return this.prisma.project.create({ data: body });
  }

  @Get()
  async list(@Query() query: any) {
    const where: any = {};
    if (query.category) where.category = query.category;
    if (query.priceMin) where.budgetMin = { gte: Number(query.priceMin) };
    if (query.priceMax) where.budgetMax = { lte: Number(query.priceMax) };
    return this.prisma.project.findMany({ where });
  }

  @Get(':id')
  async get(@Param('id') id: string) {
    return this.prisma.project.findUnique({ where: { id }, include: { proposals: true } });
  }

  @Put(':id')
  async update(@Param('id') id: string, @Body() body: any) {
    return this.prisma.project.update({ where: { id }, data: body });
  }
}
EOF

# proposals module/controller
cat > "${ROOT_DIR}/apps/backend/src/proposals/proposals.module.ts" <<'EOF'
import { Module } from '@nestjs/common';
import { ProposalsController } from './proposals.controller';
import { PrismaModule } from '../prisma/prisma.module';

@Module({
  imports: [PrismaModule],
  controllers: [ProposalsController],
})
export class ProposalsModule {}
EOF

cat > "${ROOT_DIR}/apps/backend/src/proposals/proposals.controller.ts" <<'EOF'
import { Body, Controller, Get, Param, Post } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

@Controller('projects/:projectId/proposals')
export class ProposalsController {
  constructor(private prisma: PrismaService) {}

  @Post()
  async create(@Param('projectId') projectId: string, @Body() body: any) {
    const payload = { ...body, projectId };
    return this.prisma.proposal.create({ data: payload });
  }

  @Get()
  async list(@Param('projectId') projectId: string) {
    return this.prisma.proposal.findMany({ where: { projectId } });
  }
}
EOF

# admin module/controller
cat > "${ROOT_DIR}/apps/backend/src/admin/admin.module.ts" <<'EOF'
import { Module } from '@nestjs/common';
import { AdminController } from './admin.controller';
import { PrismaModule } from '../prisma/prisma.module';

@Module({
  imports: [PrismaModule],
  controllers: [AdminController],
})
export class AdminModule {}
EOF

cat > "${ROOT_DIR}/apps/backend/src/admin/admin.controller.ts" <<'EOF'
import { Body, Controller, Get, Post } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

@Controller('admin')
export class AdminController {
  constructor(private prisma: PrismaService) {}

  @Get('settings')
  async getSettings() {
    const s = await this.prisma.adminSettings.findFirst();
    return s;
  }

  @Post('settings')
  async updateSettings(@Body() body: any) {
    const existing = await this.prisma.adminSettings.findFirst();
    if (!existing) {
      return this.prisma.adminSettings.create({ data: body });
    }
    return this.prisma.adminSettings.update({ where: { id: existing.id }, data: body });
  }
}
EOF

# conversations controller/module
cat > "${ROOT_DIR}/apps/backend/src/conversations/conversations.module.ts" <<'EOF'
import { Module } from '@nestjs/common';
import { ConversationsController } from './conversations.controller';
import { PrismaModule } from '../prisma/prisma.module';

@Module({
  imports: [PrismaModule],
  controllers: [ConversationsController],
})
export class ConversationsModule {}
EOF

cat > "${ROOT_DIR}/apps/backend/src/conversations/conversations.controller.ts" <<'EOF'
import { Body, Controller, Get, Param, Post } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

@Controller('conversations')
export class ConversationsController {
  constructor(private prisma: PrismaService) {}

  @Get(':id/messages')
  async getMessages(@Param('id') id: string) {
    return this.prisma.message.findMany({ where: { conversationId: id } });
  }

  @Post(':id/messages')
  async sendMessage(@Param('id') id: string, @Body() body: { senderId: string; content: string }) {
    const message = await this.prisma.message.create({
      data: { conversationId: id, senderId: body.senderId, content: body.content },
    });
    return message;
  }
}
EOF

# apps/frontend/package.json
cat > "${ROOT_DIR}/apps/frontend/package.json" <<'EOF'
{
  "name": "adocafreelancer-frontend",
  "version": "0.1.0",
  "private": true,
  "scripts": {
    "dev": "next dev",
    "build": "next build",
    "start": "next start",
    "lint": "next lint",
    "test": "echo \"No frontend tests configured\" && exit 0"
  },
  "dependencies": {
    "next": "14.0.0",
    "react": "18.2.0",
    "react-dom": "18.2.0"
  }
}
EOF

echo "Todos os arquivos criados em ./${ROOT_DIR}."

# create zip
ZIP_NAME="adocafreelancer-ready.zip"
if command -v zip >/dev/null 2>&1; then
  (cd "${ROOT_DIR}" && zip -r "../${ZIP_NAME}" .)
  echo "ZIP criado: ${ZIP_NAME}"
else
  echo "zip não encontrado no sistema. Instalando zip (se apt disponível)..."
  if command -v apt-get >/dev/null 2>&1; then
    sudo apt-get update && sudo apt-get install -y zip
    (cd "${ROOT_DIR}" && zip -r "../${ZIP_NAME}" .)
    echo "ZIP criado: ${ZIP_NAME}"
  else
    echo "Não foi possível criar o ZIP automaticamente - instale 'zip' e rode manualmente:"
    echo "  cd ${ROOT_DIR} && zip -r ../${ZIP_NAME} ."
  fi
fi

echo "Pronto. Extraia ou abra ${ZIP_NAME}."