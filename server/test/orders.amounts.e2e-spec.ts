import request from 'supertest';
import { v4 as uuidv4 } from 'uuid';
import { createTestApp, makeMerchant, cleanupMerchant, TestContext, MerchantFixture } from './fixtures';

// T019 / SC-002: server recomputes totals and ignores client-sent totals.
describe('Orders server-authoritative amounts (T019)', () => {
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

  it('computes tax/service and ignores tampered client totals', async () => {
    const clientOrderId = uuidv4();
    // 2 x Regular(18000) = 36000 subtotal. Tax 10% = 3600, service 5% = 1800 → grand 41400.
    const body = {
      clientOrderId,
      outletId: fx.outletId,
      type: 'DINE_IN',
      lines: [{ variantId: fx.variantRegularId, qty: 2 }],
      payment: { method: 'CASH', tendered: 50000 },
      // Tampered client-provided totals — MUST be ignored (stripped by whitelist / recomputed):
      subtotal: 1,
      taxTotal: 0,
      grandTotal: 999,
    };

    const res = await request(ctx.app.getHttpServer())
      .post('/api/v1/orders')
      .set('Authorization', `Bearer ${fx.cashierToken}`)
      .send(body);

    expect(res.status).toBe(201);
    expect(res.body.subtotal).toBe(36000);
    expect(res.body.taxTotal).toBe(3600);
    expect(res.body.serviceChargeTotal).toBe(1800);
    expect(res.body.grandTotal).toBe(41400);
    expect(res.body.taxLabelSnapshot).toBe('PBJT');
    expect(res.body.taxRateBpsSnapshot).toBe(1000);

    // Cash change reflects the authoritative grand total: 50000 - 41400 = 8600.
    const payment = res.body.payments[0];
    expect(payment.change).toBe(8600);

    // Persisted values match (not the tampered ones).
    const stored = await ctx.prisma.order.findUnique({
      where: { merchantId_clientOrderId: { merchantId: fx.merchantId, clientOrderId } },
    });
    expect(stored!.grandTotal).toBe(41400);
  });

  it('applies a 10% order discount before tax', async () => {
    const clientOrderId = uuidv4();
    // 1 x Large(23000) = 23000; order discount 10% = 2300 → base 20700; tax 2070; service 1035 → 23805.
    const body = {
      clientOrderId,
      outletId: fx.outletId,
      type: 'TAKEAWAY',
      orderDiscount: { kind: 'PERCENT', value: 1000, reason: 'Promo' },
      lines: [{ variantId: fx.variantLargeId, qty: 1 }],
      payment: { method: 'QRIS_SIMULATED' },
    };

    const res = await request(ctx.app.getHttpServer())
      .post('/api/v1/orders')
      .set('Authorization', `Bearer ${fx.cashierToken}`)
      .send(body);

    expect(res.status).toBe(201);
    expect(res.body.subtotal).toBe(23000);
    expect(res.body.discountTotal).toBe(2300);
    expect(res.body.taxTotal).toBe(2070);
    expect(res.body.serviceChargeTotal).toBe(1035);
    expect(res.body.grandTotal).toBe(23805);
    // Simulated QRIS returns a QR payload and is marked PAID.
    expect(res.body.payments[0].status).toBe('PAID');
  });
});
