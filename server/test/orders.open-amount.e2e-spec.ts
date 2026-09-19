import request from 'supertest';
import { v4 as uuidv4 } from 'uuid';
import { BusinessSize } from '@prisma/client';
import { createTestApp, makeMerchant, cleanupMerchant, TestContext, MerchantFixture } from './fixtures';
import { MAX_OPEN_AMOUNT } from '../src/common/business-size';

/**
 * Calculator-only mode (specs/008-calculator-only, Constitution III v1.8.0 — open-amount lines).
 *
 * A calculator merchant has no catalog: the cashier keys bare amounts, and each keyed amount is
 * that line's price. It is the ONE monetary value a client may originate, so most of this suite
 * is about who may NOT do it. The positive cases prove a nota records as a real sale; the negative
 * cases prove the exception stays exactly as narrow as the constitution says — and that every
 * violation is an error, never a silently-ignored field.
 */
describe('Open-amount lines (calculator-only mode)', () => {
  let ctx: TestContext;
  let calc: MerchantFixture; // UMI + calculatorOnly, no tax rule
  let general: MerchantFixture; // an ordinary catalog merchant
  let umi: MerchantFixture; // UMI, but NOT calculator-only

  beforeAll(async () => {
    ctx = await createTestApp();
    calc = await makeMerchant(ctx, { businessSize: BusinessSize.UMI, calculatorOnly: true });
    general = await makeMerchant(ctx);
    umi = await makeMerchant(ctx, { businessSize: BusinessSize.UMI });
  });
  afterAll(async () => {
    for (const fx of [calc, general, umi]) await cleanupMerchant(ctx.prisma, fx.merchantId);
    await ctx.app.close();
  });

  const api = () => request(ctx.app.getHttpServer());

  /** A nota of keyed amounts, paid in cash — the shape the calculator screen posts. */
  const nota = (fx: MerchantFixture, amounts: number[], tendered: number, clientOrderId = uuidv4()) => ({
    clientOrderId,
    outletId: fx.outletId,
    type: 'RETAIL',
    lines: amounts.map((amount) => ({ variantId: fx.openAmountVariantId, qty: 1, amount })),
    payment: { method: 'CASH', tendered },
  });

  const post = (fx: MerchantFixture, body: object, token = fx.cashierToken) =>
    api().post('/api/v1/orders').set('Authorization', `Bearer ${token}`).send(body);

  const ordersOf = (fx: MerchantFixture) => ctx.prisma.order.count({ where: { merchantId: fx.merchantId } });

  describe('a calculator merchant', () => {
    it('records a nota as a real sale: keyed amounts become qty-1 lines at their true price', async () => {
      const clientOrderId = uuidv4();
      const res = await post(calc, {
        ...nota(calc, [25000, 12000, 3000], 50000, clientOrderId),
        // Tampered client totals — discarded exactly as for any other sale.
        subtotal: 1,
        grandTotal: 999,
      });

      expect(res.status).toBe(201);
      expect(res.body.subtotal).toBe(40000);
      expect(res.body.discountTotal).toBe(0);
      // No tax rule is provisioned, so tax is zero through the engine's ordinary fallback — not a
      // calculator branch. The tax-switched-on test below is what proves that.
      expect(res.body.taxTotal).toBe(0);
      expect(res.body.serviceChargeTotal).toBe(0);
      expect(res.body.grandTotal).toBe(40000);
      expect(res.body.payments[0].tendered).toBe(50000);
      expect(res.body.payments[0].change).toBe(10000);

      const stored = await ctx.prisma.order.findUnique({
        where: { merchantId_clientOrderId: { merchantId: calc.merchantId, clientOrderId } },
        include: { lines: true },
      });
      expect(stored!.grandTotal).toBe(40000);
      // Principle IV met, not excepted: the snapshot holds the real selling price and qty stays
      // 1, so a units-sold figure counts items rather than rupiah.
      const lines = [...stored!.lines].sort((a, b) => b.lineTotal - a.lineTotal);
      expect(lines.map((l) => l.unitPriceSnapshot)).toEqual([25000, 12000, 3000]);
      expect(lines.map((l) => l.lineTotal)).toEqual([25000, 12000, 3000]);
      expect(lines.every((l) => Number(l.qty) === 1)).toBe(true);
      expect(lines.every((l) => l.variantId === calc.openAmountVariantId)).toBe(true);
      expect(lines.every((l) => l.productNameSnapshot === 'Nota')).toBe(true);
      expect(lines.every((l) => l.costPriceSnapshot === null)).toBe(true);

      // The open-amount variant is untracked: a nota never moves stock.
      const movements = await ctx.prisma.inventoryMovement.count({ where: { refId: stored!.id } });
      expect(movements).toBe(0);
    });

    it('appears in the order history the transaction window reads', async () => {
      const res = await post(calc, nota(calc, [7000], 10000));
      expect(res.status).toBe(201);

      const list = await api()
        .get('/api/v1/orders')
        .query({ outletId: calc.outletId })
        .set('Authorization', `Bearer ${calc.cashierToken}`);
      expect(list.status).toBe(200);
      const found = list.body.find((o: { id: string }) => o.id === res.body.id);
      expect(found).toBeDefined();
      expect(found.effectiveStatus).toBe('COMPLETED');
      expect(found.grandTotal).toBe(7000);
    });

    it('is idempotent on clientOrderId — a retried nota is one sale, not two', async () => {
      const clientOrderId = uuidv4();
      const first = await post(calc, nota(calc, [15000], 20000, clientOrderId));
      const again = await post(calc, nota(calc, [15000], 20000, clientOrderId));
      expect(first.status).toBe(201);
      expect(again.status).toBe(200);
      expect(again.body.id).toBe(first.body.id);
      const orders = await ctx.prisma.order.count({
        where: { merchantId: calc.merchantId, clientOrderId },
      });
      expect(orders).toBe(1);
    });

    it('refuses short cash — the server, not just the keypad', async () => {
      const before = await ordersOf(calc);
      const res = await post(calc, nota(calc, [30000], 20000));
      expect(res.status).toBe(400);
      expect(await ordersOf(calc)).toBe(before);
    });

    it('can void a nota: a reversal is written and no stock moves', async () => {
      const sale = await post(calc, nota(calc, [9000], 10000));
      expect(sale.status).toBe(201);

      const voided = await api()
        .post(`/api/v1/orders/${sale.body.id}/void`)
        .set('Authorization', `Bearer ${calc.cashierToken}`)
        .send({ reason: 'salah ketik', clientVoidId: uuidv4() });
      expect(voided.status).toBeLessThan(300);
      expect(voided.body.effectiveStatus).toBe('VOIDED');

      const reversals = await ctx.prisma.payment.count({
        where: { orderId: sale.body.id, direction: 'REVERSAL' },
      });
      expect(reversals).toBe(1);
      const movements = await ctx.prisma.inventoryMovement.count({
        where: { merchantId: calc.merchantId, variantId: calc.openAmountVariantId! },
      });
      expect(movements).toBe(0);
    });

    it('publishes the mode and the variant on /catalog, and hides the sentinel from the grid', async () => {
      const res = await api()
        .get('/api/v1/catalog')
        .query({ outletId: calc.outletId })
        .set('Authorization', `Bearer ${calc.cashierToken}`);
      expect(res.status).toBe(200);
      expect(res.body.calculatorOnly).toBe(true);
      expect(res.body.openAmountVariantId).toBe(calc.openAmountVariantId);
      const names = res.body.products.map((p: { name: string }) => p.name);
      expect(names).not.toContain('Nota');
    });

    it('keeps the sentinel out of the in-app item manager', async () => {
      const res = await api()
        .get('/api/v1/admin/products')
        .set('Authorization', `Bearer ${calc.ownerToken}`);
      expect(res.status).toBe(200);
      expect(res.body.map((p: { name: string }) => p.name)).not.toContain('Nota');
    });
  });

  // Tax must be switchable later WITHOUT a code change. If the zero were a hard-coded branch, this
  // test would fail — which is the whole reason it exists. Same figures as the Dart preview test.
  describe('tax is data, not code', () => {
    afterEach(async () => {
      await ctx.prisma.taxRule.deleteMany({ where: { merchantId: calc.merchantId } });
    });

    it('adding a TaxRule makes the same nota carry tax and service charge', async () => {
      await ctx.prisma.taxRule.create({
        data: {
          merchantId: calc.merchantId,
          outletId: calc.outletId,
          label: 'PBJT',
          rateBps: 1000,
          serviceChargeBps: 500,
          serviceLabel: 'Service',
        },
      });
      const res = await post(calc, nota(calc, [25000, 12000, 3000], 50000));
      expect(res.status).toBe(201);
      expect(res.body.subtotal).toBe(40000);
      expect(res.body.taxTotal).toBe(4000);
      expect(res.body.serviceChargeTotal).toBe(2000);
      expect(res.body.grandTotal).toBe(46000);
      expect(res.body.taxRateBpsSnapshot).toBe(1000);
    });

    it('and removing it takes the nota straight back to zero tax', async () => {
      const res = await post(calc, nota(calc, [25000, 12000, 3000], 50000));
      expect(res.status).toBe(201);
      expect(res.body.taxTotal).toBe(0);
      expect(res.body.grandTotal).toBe(40000);
    });
  });

  describe('the gate — who may NOT set a price', () => {
    it('refuses an amount from an ordinary catalog merchant, and records nothing', async () => {
      // Without an explicit refusal, `whitelist` would keep the declared key, the engine would
      // price the line off the catalog (18000), and the sale would look fine — hiding that a
      // client tried to set a price. So assert the STATUS, not just the total.
      const before = await ordersOf(general);
      const res = await post(general, {
        clientOrderId: uuidv4(),
        outletId: general.outletId,
        type: 'DINE_IN',
        lines: [{ variantId: general.variantRegularId, qty: 1, amount: 1 }],
        payment: { method: 'CASH', tendered: 50000 },
      });
      expect(res.status).toBe(403);
      expect(res.body.code).toBe('OPEN_AMOUNT_NOT_AVAILABLE');
      expect(await ordersOf(general)).toBe(before);
    });

    it('refuses a UMI merchant that is not calculator-only — the gate is the flag, not the size', async () => {
      const res = await post(umi, {
        clientOrderId: uuidv4(),
        outletId: umi.outletId,
        type: 'RETAIL',
        lines: [{ variantId: umi.variantRegularId, qty: 1, amount: 5000 }],
        payment: { method: 'CASH', tendered: 50000 },
      });
      expect(res.status).toBe(403);
      expect(res.body.code).toBe('OPEN_AMOUNT_NOT_AVAILABLE');
    });

    it("refuses a merchant aiming at another merchant's open-amount variant", async () => {
      const res = await post(general, {
        clientOrderId: uuidv4(),
        outletId: general.outletId,
        type: 'DINE_IN',
        lines: [{ variantId: calc.openAmountVariantId, qty: 1, amount: 5000 }],
        payment: { method: 'CASH', tendered: 50000 },
      });
      expect(res.status).toBe(400);
    });

    it('refuses an amount on a catalog item, even from a calculator merchant', async () => {
      const res = await post(calc, {
        clientOrderId: uuidv4(),
        outletId: calc.outletId,
        type: 'RETAIL',
        lines: [{ variantId: calc.variantRegularId, qty: 1, amount: 1 }],
        payment: { method: 'CASH', tendered: 50000 },
      });
      expect(res.status).toBe(400);
      expect(res.body.code).toBe('AMOUNT_ON_CATALOG_LINE');
    });

    it('refuses an open-amount line with no amount — it would otherwise sell for Rp 0', async () => {
      const res = await post(calc, {
        clientOrderId: uuidv4(),
        outletId: calc.outletId,
        type: 'RETAIL',
        lines: [{ variantId: calc.openAmountVariantId, qty: 1 }],
        payment: { method: 'CASH', tendered: 50000 },
      });
      expect(res.status).toBe(400);
      expect(res.body.code).toBe('OPEN_AMOUNT_REQUIRED');
    });

    it('refuses qty other than 1 — the keyed amount is the whole line', async () => {
      const body = nota(calc, [5000], 50000);
      body.lines[0].qty = 2;
      const res = await post(calc, body);
      expect(res.status).toBe(400);
      expect(res.body.code).toBe('OPEN_AMOUNT_QTY_INVALID');
    });

    it('refuses a line discount — the cashier keys the net amount', async () => {
      const body = nota(calc, [5000], 50000);
      const res = await post(calc, {
        ...body,
        lines: [{ ...body.lines[0], lineDiscount: { kind: 'AMOUNT', value: 1000 } }],
      });
      expect(res.status).toBe(400);
      expect(res.body.code).toBe('OPEN_AMOUNT_DISCOUNT_INVALID');
    });

    it.each([
      ['zero', 0],
      ['negative', -1],
      ['fractional', 1500.5],
      ['over the ceiling', MAX_OPEN_AMOUNT + 1],
    ])('refuses a %s amount', async (_label, amount) => {
      const res = await post(calc, nota(calc, [amount], MAX_OPEN_AMOUNT * 2));
      expect(res.status).toBe(400);
    });

    it('refuses an amount through revise — the second door into the money engine', async () => {
      // An open bill on the ordinary merchant, then an attempt to re-price it via revise.
      const bill = await post(general, {
        clientOrderId: uuidv4(),
        outletId: general.openBillOutletId,
        type: 'DINE_IN',
        tableLabel: 'A1',
        lines: [{ variantId: general.variantRegularId, qty: 1 }],
      });
      expect(bill.status).toBe(201);

      const revised = await api()
        .post(`/api/v1/orders/${bill.body.id}/revise`)
        .set('Authorization', `Bearer ${general.cashierToken}`)
        .send({ lines: [{ variantId: general.variantRegularId, qty: 1, amount: 1 }] });
      expect(revised.status).toBe(403);
      expect(revised.body.code).toBe('OPEN_AMOUNT_NOT_AVAILABLE');

      const stored = await ctx.prisma.order.findUnique({ where: { id: bill.body.id } });
      expect(stored!.subtotal).toBe(18000);
    });

    it("leaves an ordinary merchant's catalog exactly as it was", async () => {
      const res = await api()
        .get('/api/v1/catalog')
        .query({ outletId: general.outletId })
        .set('Authorization', `Bearer ${general.cashierToken}`);
      expect(res.status).toBe(200);
      expect(res.body.calculatorOnly).toBe(false);
      expect(res.body.openAmountVariantId).toBeNull();
      expect(res.body.products.map((p: { name: string }) => p.name)).toContain('Kopi Susu');
    });
  });
});
