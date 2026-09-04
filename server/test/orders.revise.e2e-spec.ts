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
 * Revise an open bill (add/remove items before payment).
 *
 * An open bill is pre-payment, so its lines may be replaced — but the inventory ledger is
 * still append-only: the original SALE reservation stays, and the revision writes ONE
 * ADJUSTMENT movement per variant carrying only the DELTA. Increasing beyond available
 * stock must still be refused. A COMPLETED sale is never editable (Constitution IV).
 */
describe('Open bill revision', () => {
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

  async function openBill(qty: number, variantId = fx.variantRegularId) {
    const res = await api()
      .post('/api/v1/orders')
      .set('Authorization', `Bearer ${fx.cashierToken}`)
      .send({
        clientOrderId: uuidv4(),
        outletId: fx.openBillOutletId,
        type: 'TAKEAWAY',
        lines: [{ variantId, qty }],
      })
      .expect(201);
    return res.body as { id: string; grandTotal: number; lines: unknown[] };
  }

  const revise = (id: string, lines: { variantId: string; qty: number }[]) =>
    api()
      .post(`/api/v1/orders/${id}/revise`)
      .set('Authorization', `Bearer ${fx.cashierToken}`)
      .send({ lines });

  const stockOf = async (variantId: string) =>
    Number(
      (await ctx.prisma.inventoryStock.findFirst({
        where: { outletId: fx.openBillOutletId, variantId },
      }))!.quantityOnHand,
    );

  it('adding an item reserves only the delta', async () => {
    const before = await stockOf(fx.variantRegularId);
    const bill = await openBill(2); // reserves 2

    const res = await revise(bill.id, [{ variantId: fx.variantRegularId, qty: 5 }]).expect(201);

    expect(await stockOf(fx.variantRegularId)).toBe(before - 5); // 3 more reserved, not 5
    const adjustments = await ctx.prisma.inventoryMovement.findMany({
      where: { refType: 'ORDER_REVISE', refId: bill.id },
    });
    expect(adjustments).toHaveLength(1);
    expect(Number(adjustments[0].qtyDelta)).toBe(-3); // negative = reserve more

    // The original reservation is still there, unedited.
    const sale = await ctx.prisma.inventoryMovement.findMany({
      where: { refType: 'ORDER', refId: bill.id, reason: 'SALE' },
    });
    expect(sale).toHaveLength(1);
    expect(Number(sale[0].qtyDelta)).toBe(-2);

    // Totals were recomputed server-side, not taken from the client.
    expect(res.body.grandTotal).toBeGreaterThan(bill.grandTotal);
    expect(res.body.status).toBe('AWAITING_PAYMENT');
  });

  it('removing an item releases the delta', async () => {
    const before = await stockOf(fx.variantRegularId);
    const bill = await openBill(6);

    await revise(bill.id, [{ variantId: fx.variantRegularId, qty: 2 }]).expect(201);

    expect(await stockOf(fx.variantRegularId)).toBe(before - 2);
    const adjustments = await ctx.prisma.inventoryMovement.findMany({
      where: { refType: 'ORDER_REVISE', refId: bill.id },
    });
    expect(adjustments).toHaveLength(1);
    expect(Number(adjustments[0].qtyDelta)).toBe(4); // positive = release
  });

  it('swapping a variant releases one and reserves the other', async () => {
    const regularBefore = await stockOf(fx.variantRegularId);
    const largeBefore = await stockOf(fx.variantLargeId);
    const bill = await openBill(2, fx.variantRegularId);

    await revise(bill.id, [{ variantId: fx.variantLargeId, qty: 2 }]).expect(201);

    expect(await stockOf(fx.variantRegularId)).toBe(regularBefore); // released
    expect(await stockOf(fx.variantLargeId)).toBe(largeBefore - 2); // reserved
    const adjustments = await ctx.prisma.inventoryMovement.findMany({
      where: { refType: 'ORDER_REVISE', refId: bill.id },
    });
    expect(adjustments).toHaveLength(2); // one per variant
  });

  it('refuses to reserve more than is on hand, and changes nothing when it does', async () => {
    const before = await stockOf(fx.variantRegularId);
    const bill = await openBill(1);

    await revise(bill.id, [{ variantId: fx.variantRegularId, qty: before + 50 }]).expect(400);

    expect(await stockOf(fx.variantRegularId)).toBe(before - 1); // still just the original reservation
    expect(
      await ctx.prisma.inventoryMovement.count({
        where: { refType: 'ORDER_REVISE', refId: bill.id },
      }),
    ).toBe(0);
    const lines = await ctx.prisma.orderLine.findMany({ where: { orderId: bill.id } });
    expect(lines).toHaveLength(1);
    expect(Number(lines[0].qty)).toBe(1);
  });

  it('refuses to edit a settled sale', async () => {
    const bill = await openBill(1);
    await api()
      .post(`/api/v1/orders/${bill.id}/settle`)
      .set('Authorization', `Bearer ${fx.cashierToken}`)
      .send({ clientSettleId: uuidv4(), payment: { method: 'CASH', tendered: 1000000 } })
      .expect(201);

    await revise(bill.id, [{ variantId: fx.variantRegularId, qty: 9 }]).expect(409);

    const lines = await ctx.prisma.orderLine.findMany({ where: { orderId: bill.id } });
    expect(lines).toHaveLength(1);
    expect(Number(lines[0].qty)).toBe(1); // completed history is immutable
  });
});
