import { Module } from '@nestjs/common';
import { PrismaModule } from '../prisma/prisma.module';
import { ContractsController } from './contracts.controller';
import { ContractsService } from './contracts.service';
import { PaymentsModule } from '../services/payments/payments.module';

@Module({
  imports: [PrismaModule, PaymentsModule],
  controllers: [ContractsController],
  providers: [ContractsService],
  exports: [ContractsService],
})
export class ContractsModule {}