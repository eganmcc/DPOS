import request from 'supertest';
import { v4 as uuidv4 } from 'uuid';
import { BusinessSize } from '@prisma/client';
import {
  createTestApp,
  makeMerchant,
  cleanupMerchant,
  TestContext,
  MerchantFixture,
} from './fixtures';

/**
 * Card (EDC) and e-wallet tenders.
 *
 * Two invariants matter here. First, the money is still the server's: a card sale is a normal
 * CHARGE for the server-computed grand total, and the terminal's evidence (approval code, RRN,
 * masked PAN) is stored alongside it — never used to decide an amount. Second, the tender set
 * is a commercial boundary: a UMI merchant has no acquirer relationship, so the API refuses
 * card and wallet tenders even though a UMI owner holds a genuine OWNER token.
 */
describe('Card and e-wallet tenders', () => {
  let ctx: TestContext;
  let fx: MerchantFixture;

  beforeAll(async () => {
    ctx = await createTestApp();
    fx = await makeMerchant(ctx);
  });
  afterAll(async () => {
    await cleanupMerchant(ctx.prisma, fx.merchantId);
    await ctx.app.close();
  });

  const api = () => request(ctx.app.getHttpServer());

  const edc = {
    scheme: 'VISA',
    maskedPan: '4*** **** **** 1234',
    entryMode: 'CHIP',
    approvalCode: '123456',
    rrn: '250910123456',
    traceNo: '000123',
    batchNo: '000045',
    terminalId: 'DPOS0001',
  };

  /** An immediate sale paid with the given tender. Returns the supertest request so the
   *  caller can assert its own status code. */
  function sell(payment: Record<string, unknown>, qty = 1) {
    return api()
      .post('/api/v1/orders')
      .set('Authorization', `Bearer ${fx.cashierToken}`)
      .send({
        clientOrderId: uuidv4(),
        outletId: fx.outletId,
        type: 'TAKEAWAY',
        lines: [{ variantId: fx.variantRegularId, qty }],
        payment,
      });
  }

  const paymentsOf = (orderId: string) =>
    ctx.prisma.payment.findMany({ where: { orderId }, orderBy: { createdAt: 'asc' } });

  it('stores the EDC evidence on a card sale and still owns the amount', async () => {
    const res = await sell({ method: 'CARD_DEBIT', edc }).expect(201);
    const order = res.body as { id: string; grandTotal: number };

    const [charge] = await paymentsOf(order.id);
    expect(charge.method).toBe('CARD_DEBIT');
    expect(charge.status).toBe('PAID');
    // The amount comes from the server's own computation, not from the terminal.
    expect(charge.amount).toBe(order.grandTotal);
    expect(charge.tendered).toBeNull();

    // The approval code is the payment's provider reference; the rest is evidence.
    expect(charge.providerRef).toBe(edc.approvalCode);
    const meta = charge.providerMeta as Record<string, unknown>;
    expect(meta.scheme).toBe('VISA');
    expect(meta.maskedPan).toBe(edc.maskedPan);
    expect(meta.entryMode).toBe('CHIP');
    expect(meta.rrn).toBe(edc.rrn);
    expect(meta.terminalId).toBe('DPOS0001');
  });

  it('refuses to store an unmasked PAN', async () => {
    await sell({
      method: 'CARD_CREDIT',
      edc: { ...edc, maskedPan: '4111111111111111' },
    }).expect(400);

    // Nothing was written — a rejected tender must not leave a half-made sale behind.
    const leaked = await ctx.prisma.payment.findFirst({
      where: { merchantId: fx.merchantId, providerRef: edc.approvalCode, method: 'CARD_CREDIT' },
    });
    expect(leaked).toBeNull();
  });

  it('fills in the terminal fields when a caller supplies none', async () => {
    // An API-only caller (or a future real EDC that returns less) still yields a complete,
    // reconcilable record rather than nulls.
    const res = await sell({ method: 'CARD_BCA' }).expect(201);
    const [charge] = await paymentsOf(res.body.id);
    const meta = charge.providerMeta as Record<string, unknown>;
    expect(charge.providerRef).toMatch(/^\d{6}$/); // approval code
    expect(meta.scheme).toBe('BCA'); // BCA-acquired debit
    expect(meta.acquirer).toBe('BCA');
    expect(String(meta.maskedPan)).not.toMatch(/\d{13,}/);
  });

  it('records the wallet reference on an e-wallet sale', async () => {
    const reference = uuidv4();
    const res = await sell({ method: 'EWALLET_GOPAY', wallet: { reference } }).expect(201);

    const [charge] = await paymentsOf(res.body.id);
    expect(charge.method).toBe('EWALLET_GOPAY');
    expect(charge.status).toBe('PAID');
    expect(charge.providerRef).toBe(reference);
    expect((charge.providerMeta as Record<string, unknown>).wallet).toBe('GoPay');
  });

  it('settles an open bill by card without touching stock again', async () => {
    const bill = await api()
      .post('/api/v1/orders')
      .set('Authorization', `Bearer ${fx.cashierToken}`)
      .send({
        clientOrderId: uuidv4(),
        outletId: fx.openBillOutletId,
        type: 'TAKEAWAY',
        lines: [{ variantId: fx.variantRegularId, qty: 2 }],
      })
      .expect(201);

    const movementsBefore = await ctx.prisma.inventoryMovement.count({
      where: { refType: 'ORDER', refId: bill.body.id },
    });

    const settled = await api()
      .post(`/api/v1/orders/${bill.body.id}/settle`)
      .set('Authorization', `Bearer ${fx.cashierToken}`)
      .send({ clientSettleId: uuidv4(), payment: { method: 'CARD_CREDIT', edc } })
      .expect(201);
    expect(settled.body.status).toBe('COMPLETED');

    const [charge] = await paymentsOf(bill.body.id);
    expect(charge.method).toBe('CARD_CREDIT');
    expect(charge.providerRef).toBe(edc.approvalCode);

    // Settlement moves money only — the reservation at confirm time is the only stock event.
    const movementsAfter = await ctx.prisma.inventoryMovement.count({
      where: { refType: 'ORDER', refId: bill.body.id },
    });
    expect(movementsAfter).toBe(movementsBefore);
  });

  it('reverses a card sale with its own acquirer reference, leaving the charge untouched', async () => {
    const res = await sell({ method: 'CARD_DEBIT', edc }).expect(201);
    const orderId = res.body.id as string;

    await api()
      .post(`/api/v1/orders/${orderId}/void`)
      .set('Authorization', `Bearer ${fx.ownerToken}`)
      .send({ clientVoidId: uuidv4(), reason: 'wrong card' })
      .expect(200);

    const payments = await paymentsOf(orderId);
    const charge = payments.find((p) => p.direction === 'CHARGE')!;
    const reversal = payments.find((p) => p.direction === 'REVERSAL')!;

    // The original authorization is evidence and is never rewritten (Constitution IV).
    expect(charge.providerRef).toBe(edc.approvalCode);
    expect(charge.status).toBe('PAID');

    expect(reversal.method).toBe('CARD_DEBIT');
    expect(reversal.reversalType).toBe('VOID');
    expect(reversal.providerRef).toContain(edc.approvalCode);
    expect(reversal.providerRef).not.toBe(charge.providerRef);
  });

  describe('Ultra Mikro has no acquirer relationship', () => {
    let umi: MerchantFixture;

    beforeAll(async () => {
      umi = await makeMerchant(ctx, { businessSize: BusinessSize.UMI });
    });
    afterAll(async () => {
      await cleanupMerchant(ctx.prisma, umi.merchantId);
    });

    const umiSell = (payment: Record<string, unknown>) =>
      request(ctx.app.getHttpServer())
        .post('/api/v1/orders')
        .set('Authorization', `Bearer ${umi.ownerToken}`)
        .send({
          clientOrderId: uuidv4(),
          outletId: umi.outletId,
          type: 'TAKEAWAY',
          lines: [{ variantId: umi.variantRegularId, qty: 1 }],
          payment,
        });

    it('refuses a card tender even for the owner', async () => {
      const res = await umiSell({ method: 'CARD_CREDIT', edc }).expect(403);
      expect(res.body.code).toBe('UMI_TENDER_NOT_AVAILABLE');
      expect(await ctx.prisma.order.count({ where: { merchantId: umi.merchantId } })).toBe(0);
    });

    it('refuses an e-wallet tender', async () => {
      const res = await umiSell({ method: 'EWALLET_OVO' }).expect(403);
      expect(res.body.code).toBe('UMI_TENDER_NOT_AVAILABLE');
    });

    it('still takes cash and QRIS', async () => {
      await umiSell({ method: 'CASH', tendered: 100000 }).expect(201);
      await umiSell({ method: 'QRIS_SIMULATED' }).expect(201);
      expect(await ctx.prisma.order.count({ where: { merchantId: umi.merchantId } })).toBe(2);
    });

    it('refuses a card tender when settling an open bill too', async () => {
      const bill = await request(ctx.app.getHttpServer())
        .post('/api/v1/orders')
        .set('Authorization', `Bearer ${umi.ownerToken}`)
        .send({
          clientOrderId: uuidv4(),
          outletId: umi.openBillOutletId,
          type: 'TAKEAWAY',
          lines: [{ variantId: umi.variantRegularId, qty: 1 }],
        })
        .expect(201);

      const res = await request(ctx.app.getHttpServer())
        .post(`/api/v1/orders/${bill.body.id}/settle`)
        .set('Authorization', `Bearer ${umi.ownerToken}`)
        .send({ clientSettleId: uuidv4(), payment: { method: 'CARD_BCA', edc } })
        .expect(403);
      expect(res.body.code).toBe('UMI_TENDER_NOT_AVAILABLE');

      // The bill is still open and settleable by cash.
      const still = await ctx.prisma.order.findUnique({ where: { id: bill.body.id } });
      expect(still!.status).toBe('AWAITING_PAYMENT');
    });
  });
});
