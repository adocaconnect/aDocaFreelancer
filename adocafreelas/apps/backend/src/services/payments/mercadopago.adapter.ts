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

    // For sandbox environments Mercado Pago may still use the same endpoint,
    // but you can add sandbox-specific flags if needed.
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
    // Mercado Pago webhooks usually send a topic and an id; you might need to call /v1/payments/:id
    // to get full details. Here we try to be resilient:
    try {
      // If payload has id and topic/payment info, fetch full payment
      const paymentId = payload?.data?.id || payload?.id || payload?.resource?.id || payload?.payment_id;
      if (paymentId) {
        const payment = await this.getPayment(paymentId);
        // payment structure: status, transaction_details, fee_details, id, external_reference
        const providerFee = (payment.transaction_details?.total_paid_amount || 0) - (payment.transaction_details?.net_received_amount || 0);
        return {
          status: payment.status || 'unknown',
          providerFee: providerFee || 0,
          providerTxId: String(payment.id || paymentId),
          externalReference: payment.external_reference || null,
          raw: payment,
        };
      }

      // Fallback: attempt to extract known fields
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