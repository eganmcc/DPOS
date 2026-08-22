import request from 'supertest';
import { v4 as uuidv4 } from 'uuid';
import {
  createTestApp,
  makeMerchant,
  cleanupMerchant,
  TestContext,
  MerchantFixture,
} from './fixtures';

/**
 * T035 / SC-004, SC-005 — void integrity.
 *
 * A void must be an APPEND-ONLY compensating event: the completed order and its lines are never
 * rewritten, stock comes back through a new positive movement, the actor is audited, a cashier is
 * refused — and a retried `clientVoidId` writes NOTHING a second time.
 */
describe('Order void integrity (T035)', () => {
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

  /** Rings up a sale of `qty` Regular (tracked stock) and returns the created order. */
  async function sell(qty: number, method: 'CASH' | 'QRIS_SIMULATED' = 'CASH') {
    const res = await request(ctx.app.getHttpServer())
      .post('/api/v1/orders')
      .set('Authorization', `Bearer ${fx.cashierToken}`)
      .send({
        clientOrderId: uuidv4(),
        outletId: fx.outletId,
        type: 'TAKEAWAY',
        lines: [{ variantId: fx.variantRegularId, qty }],
        payment: { method, tendered: method === 'CASH' ? 1000000 : undefined },
      })
      .expect(201);
    return res.body as {
      id: string;
      grandTotal: number;
      status: string;
      effectiveStatus: string;
      lines: { id: string; lineTotal: number }[];
    };
  }

  const stockOf = async (variantId: string) =>
    Number(
      (await ctx.prisma.inventoryStock.findFirst({ where: { outletId: fx.outletId, variantId } }))!
        .quantityOnHand,
    );

  it('appends an immutable OrderVoid, leaves the order untouched, restores stock, audits the actor', async () => {
    const order = await sell(2);
    const stockAfterSale = await stockOf(fx.variantRegularId);
    const before = (await ctx.prisma.order.findUnique({
      where: { id: order.id },
      include: { lines: true },
    }))!;

    const res = await request(ctx.app.getHttpServer())
      .post(`/api/v1/orders/${order.id}/void`)
      .set('Authorization', `Bearer ${fx.ownerToken}`)
      .send({ reason: 'wrong order', clientVoidId: uuidv4() })
      .expect(200);

    // Effective state is DERIVED — the stored status is still COMPLETED.
    expect(res.body.effectiveStatus).toBe('VOIDED');
    expect(res.body.status).toBe('COMPLETED');

    // The order and its lines are byte-for-byte what they were before the void.
    const after = (await ctx.prisma.order.findUnique({
      where: { id: order.id },
      include: { lines: true },
    }))!;
    expect(after.status).toBe('COMPLETED');
    expect(after.grandTotal).toBe(before.grandTotal);
    expect(after.subtotal).toBe(before.subtotal);
    expect(after.taxTotal).toBe(before.taxTotal);
    expect(after.serviceChargeTotal).toBe(before.serviceChargeTotal);
    expect(after.closedAt?.toISOString()).toBe(before.closedAt?.toISOString());
    expect(after.lines.map((l) => [l.id, l.lineTotal, l.qty.toString()])).toEqual(
      before.lines.map((l) => [l.id, l.lineTotal, l.qty.toString()]),
    );

    // Exactly one OrderVoid, carrying the actor and reason.
    const voids = await ctx.prisma.orderVoid.findMany({ where: { orderId: order.id } });
    expect(voids).toHaveLength(1);
    expect(voids[0].voidedById).toBe(fx.ownerId);
    expect(voids[0].reason).toBe('wrong order');

    // Stock came back through a NEW positive movement, not an edit of the sale movement.
    const restores = await ctx.prisma.inventoryMovement.findMany({
      where: { reason: 'VOID_RESTORE', refType: 'ORDER_VOID', refId: voids[0].id },
    });
    expect(restores).toHaveLength(1);
    expect(Number(restores[0].qtyDelta)).toBe(2);
    const sales = await ctx.prisma.inventoryMovement.findMany({
      where: { reason: 'SALE', refType: 'ORDER', refId: order.id },
    });
    expect(sales).toHaveLength(1);
    expect(Number(sales[0].qtyDelta)).toBe(-2); // untouched
    expect(await stockOf(fx.variantRegularId)).toBe(stockAfterSale + 2);

    // The original CHARGE is immutable; the money comes back as a new REVERSAL(VOID).
    const payments = await ctx.prisma.payment.findMany({ where: { orderId: order.id } });
    const charge = payments.find((p) => p.direction === 'CHARGE')!;
    expect(charge.status).toBe('PAID');
    expect(charge.reversalType).toBeNull();
    const reversals = payments.filter((p) => p.direction === 'REVERSAL');
    expect(reversals).toHaveLength(1);
    expect(reversals[0].reversalType).toBe('VOID');
    expect(reversals[0].reversesPaymentId).toBe(charge.id);
    expect(reversals[0].amount).toBe(order.grandTotal);
    expect(reversals[0].status).toBe('PAID');

    // A VOID-type reversal must NOT derive as REFUNDED.
    expect(res.body.effectiveStatus).not.toBe('REFUNDED');

    // Audited: who, what, when.
    const audits = await ctx.prisma.auditLog.findMany({
      where: { merchantId: fx.merchantId, entityId: order.id, action: 'VOID' },
    });
    expect(audits).toHaveLength(1);
    expect(audits[0].actorId).toBe(fx.ownerId);
    expect(audits[0].entityType).toBe('Order');
    expect((audits[0].after as Record<string, unknown>).effectiveStatus).toBe('VOIDED');
    expect((audits[0].before as Record<string, unknown>).effectiveStatus).toBe('COMPLETED');
  });

  it('refuses a CASHIER (403) and writes nothing', async () => {
    const order = await sell(1);
    const stockAfterSale = await stockOf(fx.variantRegularId);

    await request(ctx.app.getHttpServer())
      .post(`/api/v1/orders/${order.id}/void`)
      .set('Authorization', `Bearer ${fx.cashierToken}`)
      .send({ reason: 'nope', clientVoidId: uuidv4() })
      .expect(403);

    expect(await ctx.prisma.orderVoid.count({ where: { orderId: order.id } })).toBe(0);
    expect(
      await ctx.prisma.payment.count({ where: { orderId: order.id, direction: 'REVERSAL' } }),
    ).toBe(0);
    expect(
      await ctx.prisma.auditLog.count({ where: { entityId: order.id, action: 'VOID' } }),
    ).toBe(0);
    expect(await stockOf(fx.variantRegularId)).toBe(stockAfterSale);

    const fresh = (await ctx.prisma.order.findUnique({ where: { id: order.id } }))!;
    expect(fresh.status).toBe('COMPLETED');
  });

  it('is strictly idempotent: a retried clientVoidId writes exactly one of everything', async () => {
    const order = await sell(3, 'QRIS_SIMULATED');
    const stockAfterSale = await stockOf(fx.variantRegularId);
    const clientVoidId = uuidv4();

    const send = () =>
      request(ctx.app.getHttpServer())
        .post(`/api/v1/orders/${order.id}/void`)
        .set('Authorization', `Bearer ${fx.ownerToken}`)
        .send({ reason: 'double-tap', clientVoidId });

    const first = await send().expect(200);
    const second = await send().expect(200); // retry with the SAME key
    const third = await request(ctx.app.getHttpServer()) // retry with a DIFFERENT key
      .post(`/api/v1/orders/${order.id}/void`)
      .set('Authorization', `Bearer ${fx.ownerToken}`)
      .send({ reason: 'again', clientVoidId: uuidv4() })
      .expect(200);

    for (const res of [first, second, third]) {
      expect(res.body.id).toBe(order.id);
      expect(res.body.effectiveStatus).toBe('VOIDED');
      expect(res.body.status).toBe('COMPLETED');
    }

    // Exactly one OrderVoid — the first one, key and reason unchanged by the retries.
    const voids = await ctx.prisma.orderVoid.findMany({ where: { orderId: order.id } });
    expect(voids).toHaveLength(1);
    expect(voids[0].clientVoidId).toBe(clientVoidId);
    expect(voids[0].reason).toBe('double-tap');

    // Exactly one applicable REVERSAL(VOID) payment.
    const reversals = await ctx.prisma.payment.findMany({
      where: { orderId: order.id, direction: 'REVERSAL' },
    });
    expect(reversals).toHaveLength(1);
    expect(reversals[0].reversalType).toBe('VOID');

    // Exactly one set of VOID_RESTORE movements — stock restored ONCE.
    const restores = await ctx.prisma.inventoryMovement.findMany({
      where: { reason: 'VOID_RESTORE', refId: voids[0].id },
    });
    expect(restores).toHaveLength(1);
    expect(Number(restores[0].qtyDelta)).toBe(3);
    expect(await stockOf(fx.variantRegularId)).toBe(stockAfterSale + 3);

    // And one audit entry, not three.
    expect(
      await ctx.prisma.auditLog.count({ where: { entityId: order.id, action: 'VOID' } }),
    ).toBe(1);
  });

  it('holds under concurrent voids of the same order (one OrderVoid wins)', async () => {
    const order = await sell(4);
    const stockAfterSale = await stockOf(fx.variantRegularId);

    const results = await Promise.all(
      [uuidv4(), uuidv4(), uuidv4()].map((clientVoidId) =>
        request(ctx.app.getHttpServer())
          .post(`/api/v1/orders/${order.id}/void`)
          .set('Authorization', `Bearer ${fx.ownerToken}`)
          .send({ clientVoidId }),
      ),
    );
    expect(results.every((r) => r.status === 200)).toBe(true);

    const voids = await ctx.prisma.orderVoid.findMany({ where: { orderId: order.id } });
    expect(voids).toHaveLength(1);
    expect(
      await ctx.prisma.payment.count({ where: { orderId: order.id, direction: 'REVERSAL' } }),
    ).toBe(1);
    expect(
      await ctx.prisma.inventoryMovement.count({
        where: { reason: 'VOID_RESTORE', refType: 'ORDER_VOID', refId: voids[0].id },
      }),
    ).toBe(1);
    expect(await stockOf(fx.variantRegularId)).toBe(stockAfterSale + 4);
  });

  it('refuses a clientVoidId already spent on another sale (409)', async () => {
    const first = await sell(1);
    const second = await sell(1);
    const clientVoidId = uuidv4();

    await request(ctx.app.getHttpServer())
      .post(`/api/v1/orders/${first.id}/void`)
      .set('Authorization', `Bearer ${fx.ownerToken}`)
      .send({ clientVoidId })
      .expect(200);

    await request(ctx.app.getHttpServer())
      .post(`/api/v1/orders/${second.id}/void`)
      .set('Authorization', `Bearer ${fx.ownerToken}`)
      .send({ clientVoidId })
      .expect(409);

    expect(await ctx.prisma.orderVoid.count({ where: { orderId: second.id } })).toBe(0);
  });

  it('does not leak across merchants (another merchant cannot void this order)', async () => {
    const order = await sell(1);
    const other = await makeMerchant(ctx);
    try {
      await request(ctx.app.getHttpServer())
        .post(`/api/v1/orders/${order.id}/void`)
        .set('Authorization', `Bearer ${other.ownerToken}`)
        .send({ clientVoidId: uuidv4() })
        .expect(404);
      expect(await ctx.prisma.orderVoid.count({ where: { orderId: order.id } })).toBe(0);
    } finally {
      await cleanupMerchant(ctx.prisma, other.merchantId);
    }
  });

  it('lists transaction history for the outlet with derived effective status', async () => {
    const res = await request(ctx.app.getHttpServer())
      .get('/api/v1/orders')
      .query({ outletId: fx.outletId })
      .set('Authorization', `Bearer ${fx.cashierToken}`)
      .expect(200);

    const body = res.body as { id: string; effectiveStatus: string; createdAt: string }[];
    expect(body.length).toBeGreaterThan(0);
    expect(body.some((o) => o.effectiveStatus === 'VOIDED')).toBe(true);
    expect(body.some((o) => o.effectiveStatus === 'COMPLETED')).toBe(true);
    // Newest first.
    const times = body.map((o) => new Date(o.createdAt).getTime());
    expect([...times].sort((a, b) => b - a)).toEqual(times);
  });
});
