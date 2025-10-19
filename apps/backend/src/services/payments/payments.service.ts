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

  // create payment preference so client can pay
  async createDepositPreference(contractId: string, returnUrl: string) {
    const contract = await this.prisma.contract.findUnique({ where: { id: contractId } });
    if (!contract) throw new Error('Contract not found');

    const pref = await this.mpAdapter.createPreference(contract.id, contract.amount, `Escrow for contract ${contract.id}`, returnUrl || process.env.FRONTEND_URL || 'http://localhost:3000');
    return pref;
  }

  // handle webhook payload, normalize and record deposit
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

    // Create DEPOSIT transaction if none exists for this providerTxId
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

    // mark contract as HELD and store providerFeeAmount for later
    await this.prisma.contract.update({
      where: { id: contract.id },
      data: {
        escrowStatus: 'HELD',
        providerFeeAmount: verified.providerFee || 0,
      },
    });

    return { ok: true, depositTxId: depositTx.id };
  }

  // release funds to freelancer: calculate fees, create RELEASE transaction and enqueue payout job
  async releaseToFreelancer(contractId: string) {
    const contract = await this.prisma.contract.findUnique({ where: { id: contractId } });
    if (!contract) throw new Error('Contract not found');

    if (contract.escrowStatus !== 'HELD') {
      throw new Error('Contract is not in HELD state');
    }

    // providerFeeAmount was recorded at deposit time via webhook
    const providerFeeAmount = contract.providerFeeAmount ?? 0;
    const fees = calculateFees(contract.amount, contract.appliedPlatformFeePct, 0, providerFeeAmount);

    // Create RELEASE transaction
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

    // Update contract net/platform fields for auditing
    await this.prisma.contract.update({
      where: { id: contract.id },
      data: {
        escrowStatus: 'RELEASED',
        platformFeeAmount: fees.platformFeeAmount,
        netAmount: fees.netAmount,
      },
    });

    // enqueue payout job with transaction id for async processing (payout to freelancer)
    await this.payoutQueue.add('payout', {
      contractId: contract.id,
      transactionId: releaseTx.id,
      amount: fees.netAmount,
      freelancerId: contract.freelancerId,
    }, { jobId: `payout-${releaseTx.id}` });

    return { ok: true, releaseTxId: releaseTx.id, fees };
  }

  // refund flow: call MP and record REFUND transaction, mark contract refunded
  async refund(contractId: string, providerTxId: string) {
    const contract = await this.prisma.contract.findUnique({ where: { id: contractId } });
    if (!contract) throw new Error('Contract not found');

    if (!providerTxId) throw new Error('providerTxId required to refund');

    // call Mercado Pago refund
    const res = await this.mpAdapter.refund(providerTxId, contract.amount);

    // create REFUND transaction
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