import request from 'supertest';
import { v4 as uuidv4 } from 'uuid';
import {
  createTestApp,
  makeMerchant,
  cleanupMerchant,
  MANAGER_PIN,
  TestContext,
  MerchantFixture,
} from './fixtures';

/**
 * Refund a completed sale — full and line-level partial.
 *
 * Append-only, like the void: the original order, its lines and the captured CHARGE are
 * never rewritten. A refund adds a Refund record, restores the refunded stock through new
 * movements, and appends a REVERSAL/REFUND payment. Effective status becomes REFUNDED only
 * once the whole total has come back.
 */
describe('Refunds', () => {
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

  /** A settled sale of `qty` Regular on the immediate-payment outlet. */
  async function sell(qty: number) {
    const res = await api()
      .post('/api/v1/orders')
      .set('Authorization', `Bearer ${fx.cashierToken}`)
      .send({
        clientOrderId: uuidv4(),
        outletId: fx.outletId,
        type: 'TAKEAWAY',
        lines: [{ variantId: fx.variantRegularId, qty }],
        payment: { method: 'CASH', tendered: 1000000 },
      })
      .expect(201);
    return res.body as {
      id: string;
      grandTotal: number;
      lines: { id: string; variantId: string; lineTotal: number }[];
    };
  }

  const stockOf = async (variantId: string) =>
    Number(
      (await ctx.prisma.inventoryStock.findFirst({
        where: { outletId: fx.outletId, variantId },
      }))!.quantityOnHand,
    );

  it('a full refund reverses the money, restores stock, and leaves the charge immutable', async () => {
    const order = await sell(2);
    const stockAfterSale = await stockOf(fx.variantRegularId);
    const chargeBefore = (await ctx.prisma.payment.findFirst({
      where: { orderId: order.id, direction: 'CHARGE' },
    }))!;

    const res = await api()
      .post(`/api/v1/orders/${order.id}/refund`)
      .set('Authorization', `Bearer ${fx.ownerToken}`)
      .send({ clientRefundId: uuidv4(), reason: 'customer complaint', full: true })
      .expect(200);

    expect(res.body.effectiveStatus).toBe('REFUNDED');
    expect(res.body.status).toBe('COMPLETED'); // stored status never advances past COMPLETED

    const refunds = await ctx.prisma.refund.findMany({ where: { orderId: order.id } });
    expect(refunds).toHaveLength(1);
    expect(refunds[0].amount).toBe(order.grandTotal);
    expect(refunds[0].isFull).toBe(true);
    expect(refunds[0].reason).toBe('customer complaint');

    // Money back as a NEW reversal; the original charge is byte-for-byte unchanged.
    const reversals = await ctx.prisma.payment.findMany({
      where: { orderId: order.id, direction: 'REVERSAL' },
    });
    expect(reversals).toHaveLength(1);
    expect(reversals[0].reversalType).toBe('REFUND');
    expect(reversals[0].amount).toBe(order.grandTotal);
    expect(reversals[0].reversesPaymentId).toBe(chargeBefore.id);
    const chargeAfter = (await ctx.prisma.payment.findUnique({
      where: { id: chargeBefore.id },
    }))!;
    expect(chargeAfter.status).toBe(chargeBefore.status);
    expect(chargeAfter.amount).toBe(chargeBefore.amount);
    expect(chargeAfter.reversalType).toBeNull();

    // Stock came back through a new movement.
    expect(await stockOf(fx.variantRegularId)).toBe(stockAfterSale + 2);
    const restores = await ctx.prisma.inventoryMovement.findMany({
      where: { refType: 'ORDER_REFUND', refId: refunds[0].id },
    });
    expect(restores).toHaveLength(1);
    expect(Number(restores[0].qtyDelta)).toBe(2);
  });

  it('a partial refund returns only the picked quantity and does not derive REFUNDED', async () => {
    const order = await sell(4);
    const stockAfterSale = await stockOf(fx.variantRegularId);

    const res = await api()
      .post(`/api/v1/orders/${order.id}/refund`)
      .set('Authorization', `Bearer ${fx.ownerToken}`)
      .send({
        clientRefundId: uuidv4(),
        reason: 'one drink spilled',
        lines: [{ orderLineId: order.lines[0].id, qty: 1 }],
      })
      .expect(200);

    // A quarter of the bill came back — the sale is not fully refunded.
    expect(res.body.effectiveStatus).not.toBe('REFUNDED');
    const refund = (await ctx.prisma.refund.findFirst({ where: { orderId: order.id } }))!;
    expect(refund.isFull).toBe(false);
    expect(refund.amount).toBeGreaterThan(0);
    expect(refund.amount).toBeLessThan(order.grandTotal);
    expect(await stockOf(fx.variantRegularId)).toBe(stockAfterSale + 1);
  });

  it('partial refunds accumulate and cannot exceed the grand total', async () => {
    const order = await sell(2);

    // Refund line qty 1, then 1 again → the sale is now fully refunded.
    for (const _ of [1, 2]) {
      await api()
        .post(`/api/v1/orders/${order.id}/refund`)
        .set('Authorization', `Bearer ${fx.ownerToken}`)
        .send({
          clientRefundId: uuidv4(),
          reason: 'partial',
          lines: [{ orderLineId: order.lines[0].id, qty: 1 }],
        })
        .expect(200);
    }

    const refunds = await ctx.prisma.refund.findMany({ where: { orderId: order.id } });
    expect(refunds).toHaveLength(2);
    const total = refunds.reduce((s, r) => s + r.amount, 0);
    expect(total).toBeLessThanOrEqual(order.grandTotal);

    // Nothing remains — a third attempt is refused as 409 ("already fully refunded").
    await api()
      .post(`/api/v1/orders/${order.id}/refund`)
      .set('Authorization', `Bearer ${fx.ownerToken}`)
      .send({
        clientRefundId: uuidv4(),
        reason: 'over-refund attempt',
        lines: [{ orderLineId: order.lines[0].id, qty: 1 }],
      })
      .expect(409);

    expect(await ctx.prisma.refund.count({ where: { orderId: order.id } })).toBe(2);
  });

  it('is idempotent on clientRefundId', async () => {
    const order = await sell(2);
    const stockAfterSale = await stockOf(fx.variantRegularId);
    const clientRefundId = uuidv4();
    const send = () =>
      api()
        .post(`/api/v1/orders/${order.id}/refund`)
        .set('Authorization', `Bearer ${fx.ownerToken}`)
        .send({ clientRefundId, reason: 'retry after timeout', full: true });

    await send().expect(200);
    await send().expect(200); // same key → replay, no second refund

    expect(await ctx.prisma.refund.count({ where: { orderId: order.id } })).toBe(1);
    expect(
      await ctx.prisma.payment.count({ where: { orderId: order.id, direction: 'REVERSAL' } }),
    ).toBe(1);
    expect(await stockOf(fx.variantRegularId)).toBe(stockAfterSale + 2);
  });

  it('refuses an unpaid open bill (cancel is the right operation there)', async () => {
    const bill = await api()
      .post('/api/v1/orders')
      .set('Authorization', `Bearer ${fx.cashierToken}`)
      .send({
        clientOrderId: uuidv4(),
        outletId: fx.openBillOutletId,
        type: 'TAKEAWAY',
        lines: [{ variantId: fx.variantRegularId, qty: 1 }],
      })
      .expect(201);

    await api()
      .post(`/api/v1/orders/${bill.body.id}/refund`)
      .set('Authorization', `Bearer ${fx.ownerToken}`)
      .send({ clientRefundId: uuidv4(), reason: 'wrong operation', full: true })
      .expect(409);
  });

  it('a cashier needs a manager PIN', async () => {
    const order = await sell(1);
    await api()
      .post(`/api/v1/orders/${order.id}/refund`)
      .set('Authorization', `Bearer ${fx.cashierToken}`)
      .send({ clientRefundId: uuidv4(), reason: 'no approval', full: true })
      .expect(403);
    expect(await ctx.prisma.refund.count({ where: { orderId: order.id } })).toBe(0);

    await api()
      .post(`/api/v1/orders/${order.id}/refund`)
      .set('Authorization', `Bearer ${fx.cashierToken}`)
      .send({
        clientRefundId: uuidv4(),
        reason: 'approved',
        full: true,
        approverPin: MANAGER_PIN,
      })
      .expect(200);

    const refund = (await ctx.prisma.refund.findFirst({ where: { orderId: order.id } }))!;
    expect(refund.approvedById).toBe(fx.managerId); // who authorized it is on the record
  });
});
