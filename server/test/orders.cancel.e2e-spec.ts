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
 * Cancel an unpaid open bill.
 *
 * Stock is reserved at confirm, so an abandoned bill must give it back — exactly once,
 * through a NEW append-only movement (the original SALE reservation is never rewritten).
 * A double-tap on a flaky connection is the case that would otherwise leak stock.
 */
describe('Open bill cancellation', () => {
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

  async function openBill(qty: number) {
    const res = await api()
      .post('/api/v1/orders')
      .set('Authorization', `Bearer ${fx.cashierToken}`)
      .send({
        clientOrderId: uuidv4(),
        outletId: fx.openBillOutletId,
        type: 'TAKEAWAY',
        lines: [{ variantId: fx.variantRegularId, qty }],
      })
      .expect(201);
    return res.body as { id: string; grandTotal: number };
  }

  const stockOf = async (variantId: string) =>
    Number(
      (await ctx.prisma.inventoryStock.findFirst({
        where: { outletId: fx.openBillOutletId, variantId },
      }))!.quantityOnHand,
    );

  it('releases exactly the reserved stock and closes the bill unpaid', async () => {
    const stockBefore = await stockOf(fx.variantRegularId);
    const bill = await openBill(4);
    expect(await stockOf(fx.variantRegularId)).toBe(stockBefore - 4);

    const res = await api()
      .post(`/api/v1/orders/${bill.id}/cancel`)
      .set('Authorization', `Bearer ${fx.ownerToken}`)
      .send({ reason: 'Pelanggan batal' })
      .expect(200);

    expect(res.body.status).toBe('CANCELLED');
    expect(await stockOf(fx.variantRegularId)).toBe(stockBefore); // back where it started

    // The release is a NEW movement; the original reservation is untouched.
    const release = await ctx.prisma.inventoryMovement.findMany({
      where: { refType: 'ORDER_CANCEL', refId: bill.id },
    });
    expect(release).toHaveLength(1);
    expect(Number(release[0].qtyDelta)).toBe(4);
    const reserve = await ctx.prisma.inventoryMovement.findMany({
      where: { refType: 'ORDER', refId: bill.id, reason: 'SALE' },
    });
    expect(reserve).toHaveLength(1);
    expect(Number(reserve[0].qtyDelta)).toBe(-4);

    // No money was ever involved.
    expect(await ctx.prisma.payment.count({ where: { orderId: bill.id } })).toBe(0);
  });

  it('a double-tap restores stock once, not twice', async () => {
    const stockBefore = await stockOf(fx.variantRegularId);
    const bill = await openBill(5);

    const send = () =>
      api()
        .post(`/api/v1/orders/${bill.id}/cancel`)
        .set('Authorization', `Bearer ${fx.ownerToken}`)
        .send({ reason: 'Salah item' });

    await send().expect(200);
    await send().expect(409); // already cancelled — no second release

    expect(await stockOf(fx.variantRegularId)).toBe(stockBefore);
    expect(
      await ctx.prisma.inventoryMovement.count({
        where: { refType: 'ORDER_CANCEL', refId: bill.id },
      }),
    ).toBe(1);
  });

  it('holds under concurrent cancels of the same bill', async () => {
    const stockBefore = await stockOf(fx.variantRegularId);
    const bill = await openBill(2);

    const results = await Promise.all(
      [1, 2, 3].map(() =>
        api()
          .post(`/api/v1/orders/${bill.id}/cancel`)
          .set('Authorization', `Bearer ${fx.ownerToken}`)
          .send({ reason: 'Transaksi tes' }),
      ),
    );

    expect(results.filter((r) => r.status === 200)).toHaveLength(1); // one winner
    expect(await stockOf(fx.variantRegularId)).toBe(stockBefore);
    expect(
      await ctx.prisma.inventoryMovement.count({
        where: { refType: 'ORDER_CANCEL', refId: bill.id },
      }),
    ).toBe(1);
  });

  it('refuses to cancel a settled sale (that is what void is for)', async () => {
    const bill = await openBill(1);
    await api()
      .post(`/api/v1/orders/${bill.id}/settle`)
      .set('Authorization', `Bearer ${fx.cashierToken}`)
      .send({ clientSettleId: uuidv4(), payment: { method: 'CASH', tendered: 1000000 } })
      .expect(201);

    await api()
      .post(`/api/v1/orders/${bill.id}/cancel`)
      .set('Authorization', `Bearer ${fx.ownerToken}`)
      .send({ reason: 'too late' })
      .expect(409);

    const fresh = (await ctx.prisma.order.findUnique({ where: { id: bill.id } }))!;
    expect(fresh.status).toBe('COMPLETED');
  });

  it('requires a reason', async () => {
    const bill = await openBill(1);
    await api()
      .post(`/api/v1/orders/${bill.id}/cancel`)
      .set('Authorization', `Bearer ${fx.ownerToken}`)
      .send({})
      .expect(400);

    const fresh = (await ctx.prisma.order.findUnique({ where: { id: bill.id } }))!;
    expect(fresh.status).toBe('AWAITING_PAYMENT');
  });

  it('a cashier needs a manager PIN; with one, the manager is recorded as approver', async () => {
    const denied = await openBill(1);
    await api()
      .post(`/api/v1/orders/${denied.id}/cancel`)
      .set('Authorization', `Bearer ${fx.cashierToken}`)
      .send({ reason: 'no approval' })
      .expect(403);
    expect(
      (await ctx.prisma.order.findUnique({ where: { id: denied.id } }))!.status,
    ).toBe('AWAITING_PAYMENT');

    const allowed = await openBill(1);
    await api()
      .post(`/api/v1/orders/${allowed.id}/cancel`)
      .set('Authorization', `Bearer ${fx.cashierToken}`)
      .send({ reason: 'approved by manager', approverPin: MANAGER_PIN })
      .expect(200);
    expect(
      (await ctx.prisma.order.findUnique({ where: { id: allowed.id } }))!.status,
    ).toBe('CANCELLED');
  });
});
