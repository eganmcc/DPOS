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
 * Settle an open bill (deferred settlement, Constitution 1.2.0).
 *
 * The invariant that matters: stock is reserved when the bill is CONFIRMED, so settling
 * moves money ONLY — it must never touch inventory a second time. The conditional status
 * flip is what makes a retry (or two cashiers tapping at once) safe.
 */
describe('Open bill settlement', () => {
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

  /** Confirm an open bill: a submit with NO payment block. */
  async function openBill(qty: number, tableLabel?: string) {
    const res = await api()
      .post('/api/v1/orders')
      .set('Authorization', `Bearer ${fx.cashierToken}`)
      .send({
        clientOrderId: uuidv4(),
        outletId: fx.openBillOutletId,
        type: tableLabel ? 'DINE_IN' : 'TAKEAWAY',
        ...(tableLabel ? { tableLabel } : {}),
        lines: [{ variantId: fx.variantRegularId, qty }],
      })
      .expect(201);
    return res.body as { id: string; status: string; grandTotal: number };
  }

  const stockOf = async (variantId: string) =>
    Number(
      (await ctx.prisma.inventoryStock.findFirst({
        where: { outletId: fx.openBillOutletId, variantId },
      }))!.quantityOnHand,
    );

  it('confirming an open bill reserves stock and captures no payment', async () => {
    const before = await stockOf(fx.variantRegularId);
    const bill = await openBill(2);

    expect(bill.status).toBe('AWAITING_PAYMENT');
    expect(await stockOf(fx.variantRegularId)).toBe(before - 2); // reserved at confirm
    const payments = await ctx.prisma.payment.findMany({ where: { orderId: bill.id } });
    expect(payments).toHaveLength(0); // no money yet
    const sales = await ctx.prisma.inventoryMovement.findMany({
      where: { refType: 'ORDER', refId: bill.id, reason: 'SALE' },
    });
    expect(sales).toHaveLength(1);
    expect(Number(sales[0].qtyDelta)).toBe(-2);
  });

  it('settling appends exactly one CHARGE and does not touch stock again', async () => {
    const bill = await openBill(3);
    const stockAfterConfirm = await stockOf(fx.variantRegularId);
    const movementsBefore = await ctx.prisma.inventoryMovement.count({
      where: { refId: bill.id },
    });

    const res = await api()
      .post(`/api/v1/orders/${bill.id}/settle`)
      .set('Authorization', `Bearer ${fx.cashierToken}`)
      .send({ clientSettleId: uuidv4(), payment: { method: 'CASH', tendered: 1000000 } })
      .expect(201); // 201 = settled now, 200 = idempotent replay

    expect(res.body.status).toBe('COMPLETED');
    expect(res.body.effectiveStatus).toBe('COMPLETED');

    const payments = await ctx.prisma.payment.findMany({ where: { orderId: bill.id } });
    expect(payments).toHaveLength(1);
    expect(payments[0].direction).toBe('CHARGE');
    expect(payments[0].status).toBe('PAID');
    expect(payments[0].amount).toBe(bill.grandTotal); // charged the stored, server-authoritative total

    // The whole point: settlement is money-only.
    expect(await stockOf(fx.variantRegularId)).toBe(stockAfterConfirm);
    expect(await ctx.prisma.inventoryMovement.count({ where: { refId: bill.id } })).toBe(
      movementsBefore,
    );
  });

  it('a retried settle replays instead of double-charging', async () => {
    const bill = await openBill(1);
    const clientSettleId = uuidv4();
    const send = () =>
      api()
        .post(`/api/v1/orders/${bill.id}/settle`)
        .set('Authorization', `Bearer ${fx.cashierToken}`)
        .send({ clientSettleId, payment: { method: 'CASH', tendered: 1000000 } });

    await send().expect(201);
    const second = await send().expect(200); // same key, dropped-reply retry → replay

    expect(second.body.status).toBe('COMPLETED');
    expect(await ctx.prisma.payment.count({ where: { orderId: bill.id } })).toBe(1);
  });

  it('holds under two cashiers settling the same bill at once', async () => {
    const bill = await openBill(1);
    const results = await Promise.all(
      [1, 2, 3].map(() =>
        api()
          .post(`/api/v1/orders/${bill.id}/settle`)
          .set('Authorization', `Bearer ${fx.cashierToken}`)
          .send({ clientSettleId: uuidv4(), payment: { method: 'CASH', tendered: 1000000 } }),
      ),
    );

    // Exactly one request wins the flip (201); the losers replay (200).
    expect(results.filter((r) => r.status === 201)).toHaveLength(1);
    expect(results.every((r) => r.status === 200 || r.status === 201)).toBe(true);
    expect(await ctx.prisma.payment.count({ where: { orderId: bill.id } })).toBe(1);
    const fresh = (await ctx.prisma.order.findUnique({ where: { id: bill.id } }))!;
    expect(fresh.status).toBe('COMPLETED');
  });

  it('refuses to settle a cancelled bill', async () => {
    const bill = await openBill(1);
    await api()
      .post(`/api/v1/orders/${bill.id}/cancel`)
      .set('Authorization', `Bearer ${fx.ownerToken}`)
      .send({ reason: 'customer left' })
      .expect(200);

    await api()
      .post(`/api/v1/orders/${bill.id}/settle`)
      .set('Authorization', `Bearer ${fx.cashierToken}`)
      .send({ clientSettleId: uuidv4(), payment: { method: 'CASH', tendered: 1000000 } })
      .expect(409);

    expect(await ctx.prisma.payment.count({ where: { orderId: bill.id } })).toBe(0);
  });

  it('one open bill per table: a second bill on the same table is refused', async () => {
    await openBill(1, 'A1');
    await api()
      .post('/api/v1/orders')
      .set('Authorization', `Bearer ${fx.cashierToken}`)
      .send({
        clientOrderId: uuidv4(),
        outletId: fx.openBillOutletId,
        type: 'DINE_IN',
        tableLabel: 'a1', // same table, different case
        lines: [{ variantId: fx.variantRegularId, qty: 1 }],
      })
      .expect(409);
  });

  it('lists open bills for the outlet', async () => {
    const res = await api()
      .get('/api/v1/orders/open')
      .query({ outletId: fx.openBillOutletId })
      .set('Authorization', `Bearer ${fx.cashierToken}`)
      .expect(200);

    const body = res.body as { id: string; status: string }[];
    expect(body.length).toBeGreaterThan(0);
    expect(body.every((o) => o.status === 'AWAITING_PAYMENT')).toBe(true);
  });
});
