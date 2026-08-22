import request from 'supertest';
import { v4 as uuidv4 } from 'uuid';
import { createTestApp, makeMerchant, cleanupMerchant, TestContext, MerchantFixture } from './fixtures';

// T018 / SC-003: POST /orders is idempotent on (merchantId, clientOrderId).
describe('Orders idempotency (T018)', () => {
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

  it('duplicate submit yields exactly one order and one stock decrement', async () => {
    const clientOrderId = uuidv4();
    const body = {
      clientOrderId,
      outletId: fx.outletId,
      type: 'TAKEAWAY',
      lines: [{ variantId: fx.variantRegularId, qty: 2 }], // 2 x 18000
      payment: { method: 'CASH', tendered: 100000 },
    };
    const server = ctx.app.getHttpServer();

    const first = await request(server)
      .post('/api/v1/orders')
      .set('Authorization', `Bearer ${fx.cashierToken}`)
      .send(body);
    expect(first.status).toBe(201);

    const second = await request(server)
      .post('/api/v1/orders')
      .set('Authorization', `Bearer ${fx.cashierToken}`)
      .send(body);
    expect(second.status).toBe(200); // idempotent replay
    expect(second.body.id).toBe(first.body.id);

    // Exactly one order for this clientOrderId.
    const orders = await ctx.prisma.order.findMany({ where: { merchantId: fx.merchantId, clientOrderId } });
    expect(orders).toHaveLength(1);

    // Exactly one SALE movement of -2 for the variant.
    const moves = await ctx.prisma.inventoryMovement.findMany({
      where: { merchantId: fx.merchantId, variantId: fx.variantRegularId, reason: 'SALE' },
    });
    expect(moves).toHaveLength(1);
    expect(Number(moves[0].qtyDelta)).toBe(-2);

    // Stock decremented once: 100 - 2 = 98.
    const stock = await ctx.prisma.inventoryStock.findFirst({
      where: { outletId: fx.outletId, variantId: fx.variantRegularId },
    });
    expect(Number(stock!.quantityOnHand)).toBe(98);
  });
});
