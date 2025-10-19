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