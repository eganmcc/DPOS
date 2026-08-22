import request from 'supertest';
import { v4 as uuidv4 } from 'uuid';
import { createTestApp, makeMerchant, cleanupMerchant, TestContext, MerchantFixture } from './fixtures';

// T020 / SC-006: an induced mid-checkout failure leaves NO partial record (all-or-nothing).
describe('Orders atomicity (T020)', () => {
  let ctx: TestContext;
  let fx: MerchantFixture;

  beforeAll(async () => {
    ctx = await createTestApp();
    fx = await makeMerchant(ctx);
    // Inject a failure INSIDE the checkout transaction: throw when the Payment row is created,
    // which happens after the Order + OrderLines have been written. A correct implementation
    // rolls the whole thing back.
    ctx.prisma.$use(async (params, next) => {
      if (params.model === 'Payment' && params.action === 'create') {
        throw new Error('injected mid-transaction failure');
      }
      return next(params);
    });
  });
  afterAll(async () => {
    await cleanupMerchant(ctx.prisma, fx.merchantId);
    await ctx.app.close();
  });

  it('rolls back order, lines, and stock when a later step fails', async () => {
    const clientOrderId = uuidv4();
    const res = await request(ctx.app.getHttpServer())
      .post('/api/v1/orders')
      .set('Authorization', `Bearer ${fx.cashierToken}`)
      .send({
        clientOrderId,
        outletId: fx.outletId,
        type: 'TAKEAWAY',
        lines: [{ variantId: fx.variantRegularId, qty: 3 }],
        payment: { method: 'CASH', tendered: 100000 },
      });

    expect(res.status).toBeGreaterThanOrEqual(500); // the injected failure surfaces as a server error

    // Nothing persisted: no order, no lines, no movements, and stock untouched (still 100).
    const order = await ctx.prisma.order.findUnique({
      where: { merchantId_clientOrderId: { merchantId: fx.merchantId, clientOrderId } },
    });
    expect(order).toBeNull();

    const moves = await ctx.prisma.inventoryMovement.findMany({
      where: { merchantId: fx.merchantId, variantId: fx.variantRegularId, reason: 'SALE' },
    });
    expect(moves).toHaveLength(0);

    const stock = await ctx.prisma.inventoryStock.findFirst({
      where: { outletId: fx.outletId, variantId: fx.variantRegularId },
    });
    expect(Number(stock!.quantityOnHand)).toBe(100);
  });
});
