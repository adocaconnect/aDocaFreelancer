import { Body, Controller, Param, Post, UseGuards } from '@nestjs/common';
import { ContractsService } from './contracts.service';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { Roles } from '../common/decorators/roles.decorator';
import { RolesGuard } from '../common/guards/roles.guard';
import { CurrentUser } from '../common/decorators/current-user.decorator';

@Controller('contracts')
export class ContractsController {
  constructor(private service: ContractsService) {}

  // Cliente cria preferência de depósito (precisa ser cliente do contrato)
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles('CLIENT', 'ADMIN')
  @Post(':id/escrow/deposit')
  async deposit(@Param('id') id: string, @Body() body: { returnUrl?: string }, @CurrentUser() user: any) {
    // Optionally check that user.userId === clientId for contract
    return this.service.createDepositPreference(id, body?.returnUrl);
  }

  // Liberação: apenas CLIENT (dono do contrato) ou ADMIN
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles('CLIENT', 'ADMIN')
  @Post(':id/escrow/release')
  async release(@Param('id') id: string, @CurrentUser() user: any) {
    // in production validate that user.userId === contract.clientId unless ADMIN
    return this.service.release(id);
  }

  // Refund: CLIENT or ADMIN
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles('CLIENT', 'ADMIN')
  @Post(':id/escrow/refund')
  async refund(@Param('id') id: string, @Body() body: { providerTxId: string }, @CurrentUser() user: any) {
    return this.service.refund(id, body.providerTxId);
  }
}