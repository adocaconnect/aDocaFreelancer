import { Worker } from 'bullmq';
import IORedis from 'ioredis';
import { PrismaClient } from '@prisma/client';
import { v4 as uuidv4 } from 'uuid';

const REDIS_URL = process.env.REDIS_URL || 'redis://localhost:6379';
const connection = new IORedis(REDIS_URL);
const prisma = new PrismaClient();

/**
 * Payout worker (BullMQ)
 *
 * This worker processes jobs added to 'payouts' queue.
 * In production you will call provider-specific payout APIs (Mercado Pago/others),
 * handle errors, retries, and reconciliation.
 *
 * Here we simulate a payout by creating a fake provider payout id and updating the transaction record.
 */
const worker = new Worker(
  'payouts',
  async (job) => {
    const { contractId, transactionId, amount, freelancerId } = job.data as any;
    // Simulate provider payout processing
    // In real life: call provider Payout API, record provider payout tx id,
    // update transaction.providerTxId and create ledger events.

    const providerPayoutId = `payout_${uuidv4()}`;

    // Update transaction with providerTxId
    await prisma.transaction.update({
      where: { id: transactionId },
      data: {
        providerTxId: providerPayoutId,
      },
    });

    // Optional: update contract or create payout record
    await prisma.contract.update({
      where: { id: contractId },
      data: {
        escrowStatus: 'RELEASED',
      },
    });

    // You can also record a separate ledger entry for the actual provider payout if desired
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