import { Module } from '@nestjs/common';
import { PrismaModule } from '../prisma/prisma.module';
import { WebhooksController } from './webhooks.controller';
import { PaymentsModule } from '../services/payments/payments.module';

@Module({
  imports: [PrismaModule, PaymentsModule],
  controllers: [WebhooksController],
})
export class WebhooksModule {}