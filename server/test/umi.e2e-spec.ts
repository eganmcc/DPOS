import request from 'supertest';
import { v4 as uuidv4 } from 'uuid';
import {
  createTestApp,
  makeMerchant,
  cleanupMerchant,
  OWNER_PASSWORD,
  TestContext,
  MerchantFixture,
} from './fixtures';

/**
 * UMI (Ultra Mikro) — a single-person business size.
 *
 * A UMI merchant has nobody to approve a correction, so the manager-PIN override is bypassed
 * for EVERY role. What must NOT change: the correction is still append-only, stock still comes
 * back through the ledger, and the REASON IS STILL MANDATORY — it is the audit record, and the
 * whole point of this suite is proving it wasn't traded away for convenience.
 *
 * A GENERAL fixture runs beside the UMI one throughout: every bypass must be inert for it.
 * The orders.void / orders.cancel / orders.refund suites are the wider regression fence.
 */
describe('UMI (Ultra Mikro) business size', () => {
  let ctx: TestContext;
  let umi: MerchantFixture;
  let general: MerchantFixture;
  let pl: MerchantFixture; // its own merchant: the P/L assertions are exact totals

  beforeAll(async () => {
    ctx = await createTestApp();
    umi = await makeMerchant(ctx, { businessSize: 'UMI' });
    general = await makeMerchant(ctx);
    pl = await makeMerchant(ctx);
  });
  afterAll(async () => {
    await cleanupMerchant(ctx.prisma, umi.merchantId);
    await cleanupMerchant(ctx.prisma, general.merchantId);
    await cleanupMerchant(ctx.prisma, pl.merchantId);
    await ctx.app.close();
  });

  const srv = () => ctx.app.getHttpServer();

  /** Rings up a paid sale of `qty` Regular at the immediate-payment outlet. */
  async function sell(fx: MerchantFixture, qty: number) {
    const res = await request(srv())
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
    return res.body as { id: string; grandTotal: number };
  }

  /** Confirms an unpaid open bill (reserves stock) at the open-bill outlet. */
  async function openBill(fx: MerchantFixture, qty: number) {
    const res = await request(srv())
      .post('/api/v1/orders')
      .set('Authorization', `Bearer ${fx.cashierToken}`)
      .send({
        clientOrderId: uuidv4(),
        outletId: fx.openBillOutletId,
        type: 'DINE_IN',
        lines: [{ variantId: fx.variantRegularId, qty }],
      })
      .expect(201);
    return res.body as { id: string; status: string };
  }

  const stockOf = async (outletId: string, variantId: string) =>
    Number(
      (await ctx.prisma.inventoryStock.findFirst({ where: { outletId, variantId } }))!
        .quantityOnHand,
    );

  const auditAfter = async (merchantId: string, entityId: string, action: string) => {
    const log = await ctx.prisma.auditLog.findFirst({
      where: { merchantId, entityId, action },
      orderBy: { createdAt: 'desc' },
    });
    return log?.after as Record<string, unknown> | undefined;
  };

  // ---------------------------------------------------------------- corrections

  it('a UMI CASHIER voids with no approver PIN — append-only, stock restored, basis recorded', async () => {
    const before = await stockOf(umi.outletId, umi.variantRegularId);
    const order = await sell(umi, 2);
    expect(await stockOf(umi.outletId, umi.variantRegularId)).toBe(before - 2);

    await request(srv())
      .post(`/api/v1/orders/${order.id}/void`)
      .set('Authorization', `Bearer ${umi.cashierToken}`)
      .send({ clientVoidId: uuidv4(), reason: 'salah pesan' }) // NO approverPin
      .expect(200);

    // Append-only: the void exists, self-authorized, and the order itself is untouched.
    const v = await ctx.prisma.orderVoid.findFirst({ where: { orderId: order.id } });
    expect(v).toBeTruthy();
    expect(v!.approvedById).toBeNull();
    expect(v!.voidedById).toBe(umi.cashierId);
    expect(v!.reason).toBe('salah pesan');
    const stored = await ctx.prisma.order.findUnique({ where: { id: order.id } });
    expect(stored!.status).toBe('COMPLETED'); // never rewritten; VOIDED is derived

    // Stock came back, and exactly one reversal payment was written.
    expect(await stockOf(umi.outletId, umi.variantRegularId)).toBe(before);
    const reversals = await ctx.prisma.payment.count({
      where: { orderId: order.id, direction: 'REVERSAL' },
    });
    expect(reversals).toBe(1);

    // The discriminator: null approver is explained, not ambiguous.
    expect(await auditAfter(umi.merchantId, order.id, 'VOID')).toMatchObject({
      approvedById: null,
      approvalBasis: 'UMI_BYPASS',
    });
  });

  it('a UMI void with NO REASON is still refused, and writes nothing', async () => {
    const order = await sell(umi, 1);
    const stockAfterSale = await stockOf(umi.outletId, umi.variantRegularId);

    await request(srv())
      .post(`/api/v1/orders/${order.id}/void`)
      .set('Authorization', `Bearer ${umi.cashierToken}`)
      .send({ clientVoidId: uuidv4() }) // no reason
      .expect(400);

    expect(await ctx.prisma.orderVoid.count({ where: { orderId: order.id } })).toBe(0);
    expect(await stockOf(umi.outletId, umi.variantRegularId)).toBe(stockAfterSale);
  });

  it('a UMI CASHIER cancels an unpaid open bill with no PIN — reserved stock released', async () => {
    const before = await stockOf(umi.openBillOutletId, umi.variantRegularId);
    const bill = await openBill(umi, 3);
    expect(await stockOf(umi.openBillOutletId, umi.variantRegularId)).toBe(before - 3);

    await request(srv())
      .post(`/api/v1/orders/${bill.id}/cancel`)
      .set('Authorization', `Bearer ${umi.cashierToken}`)
      .send({ reason: 'pembeli batal' })
      .expect(200);

    const stored = await ctx.prisma.order.findUnique({ where: { id: bill.id } });
    expect(stored!.status).toBe('CANCELLED');
    expect(await stockOf(umi.openBillOutletId, umi.variantRegularId)).toBe(before);
    expect(await auditAfter(umi.merchantId, bill.id, 'CANCEL_OPEN_BILL')).toMatchObject({
      approvalBasis: 'UMI_BYPASS',
    });
  });

  it('a UMI CASHIER refunds in full with no PIN', async () => {
    const order = await sell(umi, 1);

    await request(srv())
      .post(`/api/v1/orders/${order.id}/refund`)
      .set('Authorization', `Bearer ${umi.cashierToken}`)
      .send({ clientRefundId: uuidv4(), reason: 'barang rusak', full: true })
      .expect(200);

    const refund = await ctx.prisma.refund.findFirst({ where: { orderId: order.id } });
    expect(refund).toBeTruthy();
    expect(refund!.approvedById).toBeNull();
    expect(refund!.amount).toBe(order.grandTotal);
  });

  it('a GENERAL cashier is still refused without a PIN (the bypass has not leaked)', async () => {
    const order = await sell(general, 1);
    await request(srv())
      .post(`/api/v1/orders/${order.id}/void`)
      .set('Authorization', `Bearer ${general.cashierToken}`)
      .send({ clientVoidId: uuidv4(), reason: 'should not pass' })
      .expect(403);
    expect(await ctx.prisma.orderVoid.count({ where: { orderId: order.id } })).toBe(0);
  });

  it('a GENERAL owner self-authorizes and records basis SELF', async () => {
    const order = await sell(general, 1);
    await request(srv())
      .post(`/api/v1/orders/${order.id}/void`)
      .set('Authorization', `Bearer ${general.ownerToken}`)
      .send({ clientVoidId: uuidv4(), reason: 'owner void' })
      .expect(200);
    expect(await auditAfter(general.merchantId, order.id, 'VOID')).toMatchObject({
      approvalBasis: 'SELF',
    });
  });

  // ---------------------------------------------------------------- portal + staff

  it('refuses portal (email/password) login for UMI, but not for GENERAL', async () => {
    const refused = await request(srv())
      .post('/api/v1/auth/login')
      .send({ email: umi.ownerEmail, password: OWNER_PASSWORD })
      .expect(403);
    expect(refused.body.code).toBe('PORTAL_NOT_AVAILABLE');

    const ok = await request(srv())
      .post('/api/v1/auth/login')
      .send({ email: general.ownerEmail, password: OWNER_PASSWORD })
      .expect(201);
    expect(ok.body.token).toBeTruthy();
  });

  it('a wrong password is still 401 for UMI — the tier is never leaked to a prober', async () => {
    await request(srv())
      .post('/api/v1/auth/login')
      .send({ email: umi.ownerEmail, password: 'wrong-password' })
      .expect(401);
  });

  it('refuses staff creation for UMI (single-user), but allows rename', async () => {
    const before = await ctx.prisma.staff.count({ where: { merchantId: umi.merchantId } });
    const res = await request(srv())
      .post('/api/v1/admin/staff')
      .set('Authorization', `Bearer ${umi.ownerToken}`)
      .send({ name: 'Second Person', role: 'CASHIER', pin: '5555' })
      .expect(403);
    expect(res.body.code).toBe('UMI_SINGLE_USER');
    expect(await ctx.prisma.staff.count({ where: { merchantId: umi.merchantId } })).toBe(before);

    // The sole owner must still be able to maintain their own account.
    await request(srv())
      .patch(`/api/v1/admin/staff/${umi.ownerId}`)
      .set('Authorization', `Bearer ${umi.ownerToken}`)
      .send({ name: 'Owner Renamed' })
      .expect(200);
  });

  // ---------------------------------------------------------------- item cap

  it('caps a UMI catalog at 30 products; GENERAL is uncapped', async () => {
    const category = await ctx.prisma.category.findFirst({ where: { merchantId: umi.merchantId } });
    // The fixture already created 1 product; fill to exactly the limit.
    const existing = await ctx.prisma.product.count({
      where: { merchantId: umi.merchantId, isAvailable: true },
    });
    for (let i = existing; i < 30; i++) {
      await ctx.prisma.product.create({
        data: { merchantId: umi.merchantId, categoryId: category!.id, name: `Filler ${i}` },
      });
    }
    expect(
      await ctx.prisma.product.count({ where: { merchantId: umi.merchantId, isAvailable: true } }),
    ).toBe(30);

    const res = await request(srv())
      .post('/api/v1/admin/products')
      .set('Authorization', `Bearer ${umi.ownerToken}`)
      .send({ name: 'One Too Many', categoryName: 'Cat', price: 10000, trackInventory: false })
      .expect(400);
    expect(res.body.code).toBe('ITEM_LIMIT_REACHED');
    expect(res.body.limit).toBe(30);
    // The message must not promise a self-service escape that does not exist.
    expect(String(res.body.message)).not.toMatch(/switch/i);
    expect(
      await ctx.prisma.product.count({ where: { merchantId: umi.merchantId, isAvailable: true } }),
    ).toBe(30);

    // A GENERAL merchant at the same count is unaffected.
    await request(srv())
      .post('/api/v1/admin/products')
      .set('Authorization', `Bearer ${general.ownerToken}`)
      .send({ name: 'Uncapped', categoryName: 'Cat', price: 10000, trackInventory: false })
      .expect(201);
  });

  // ---------------------------------------------------------------- gross margin (P/L)

  it('reports gross margin from costPriceSnapshot, flags missing costs, leaves netSales alone', async () => {
    const COST = 7000; // Regular sells at 18000
    await ctx.prisma.productVariant.update({
      where: { id: pl.variantRegularId },
      data: { costPrice: COST },
    });
    // variantLarge deliberately keeps costPrice = null — the missing-cost case.

    const a = await sell(pl, 2); // costed line, qty 2
    const b = await request(srv())
      .post('/api/v1/orders')
      .set('Authorization', `Bearer ${pl.cashierToken}`)
      .send({
        clientOrderId: uuidv4(),
        outletId: pl.outletId,
        type: 'TAKEAWAY',
        lines: [{ variantId: pl.variantLargeId, qty: 1 }], // uncosted line
        payment: { method: 'CASH', tendered: 1000000 },
      })
      .expect(201);

    const res = await request(srv())
      .get('/api/v1/admin/dashboard')
      .set('Authorization', `Bearer ${pl.ownerToken}`)
      .expect(200);
    const d = res.body;

    // COGS is per-unit cost x qty — only the costed line contributes.
    expect(d.cogs).toBe(COST * 2);
    expect(d.grossProfit).toBe(d.netRevenue - d.cogs);
    expect(d.grossMarginBps).toBe(Math.round((d.grossProfit / d.netRevenue) * 10000));

    // The uncosted line is surfaced, not swallowed.
    expect(d.costCoverage.linesTotal).toBe(2);
    expect(d.costCoverage.linesMissingCost).toBe(1);
    expect(d.costCoverage.itemsMissingCost).toContain('Kopi Susu');

    // Margin is computed on revenue excluding tax/service, so it is strictly below
    // the tax-inclusive total — the fixture charges PBJT 10% + 5% service.
    const grandTotal = a.grandTotal + b.body.grandTotal;
    expect(d.netSales).toBe(grandTotal); // the existing contract is untouched
    expect(d.netRevenue).toBeLessThan(d.netSales);
  });
});
