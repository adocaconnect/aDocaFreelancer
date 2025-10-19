import { Body, Controller, Post, Req } from '@nestjs/common';
import { PaymentsService } from '../services/payments/payments.service';

@Controller('webhooks')
export class WebhooksController {
  constructor(private payments: PaymentsService) {}

  // Mercado Pago webhook endpoint
  @Post('mercadopago')
  async mercadopago(@Req() req: any, @Body() body: any) {
    // For security: validate headers and topic when possible. Here we pass body to service which calls MP for full details.
    const res = await this.payments.handleProviderNotification(body);
    return res;
  }
}