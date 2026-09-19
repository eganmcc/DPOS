import request from 'supertest';
import { v4 as uuidv4 } from 'uuid';
import { BusinessType } from '@prisma/client';
import { createTestApp, makeMerchant, cleanupMerchant, TestContext, MerchantFixture } from './fixtures';
import { MAX_OPEN_AMOUNT_LABEL } from '../src/common/business-size';

/**
 * Nota reading mode (specs/009, Constitution III v1.9.0).
 *
 * A HIGH_HUMAN_INTERACTION merchant sells from its own paper: a photographed nota is read, the
 * cashier confirms it, and it becomes an OPEN transaction — settled later through the ordinary
 * settle path. Each priced line is an open-amount line at the price written on the paper, named as
 * written. This suite proves the sale records and settles correctly, that one nota can only ever
 * be one sale, and that labels can never rename a catalog item.
 */
describe('Nota sales (High Human Interactions)', () => {
  let ctx: TestContext;
  let hhi: MerchantFixture; // HIGH_HUMAN_INTERACTION, GENERAL size, no tax rule
  let general: MerchantFixture; // an ordinary F&B catalog merchant

  beforeAll(async () => {
    ctx = await createTestApp();
    hhi = await makeMerchant(ctx, { businessType: BusinessType.HIGH_HUMAN_INTERACTION });
    general = await makeMerchant(ctx);
  });
  afterAll(async () => {
    for (const fx of [hhi, general]) await cleanupMerchant(ctx.prisma, fx.merchantId);
    await ctx.app.close();
  });

  const api = () => request(ctx.app.getHttpServer());

  /** A confirmed nota, as the nota chat posts it: priced lines, no payment → an open bill. */
  const notaSale = (
    notaNumber: string | null,
    lines: { label: string; amount: number }[],
    clientOrderId = uuidv4(),
  ) => ({
    clientOrderId,
    outletId: hhi.outletId,
    type: 'RETAIL',
    ...(notaNumber ? { notaNumber } : {}),
    customerName: 'Edward',
    lines: lines.map((l) => ({ variantId: hhi.openAmountVariantId, qty: 1, ...l })),
  });

  const post = (fx: MerchantFixture, body: object, token = fx.cashierToken) =>
    api().post('/api/v1/orders').set('Authorization', `Bearer ${token}`).send(body);

  const settle = (orderId: string, tendered: number) =>
    api()
      .post(`/api/v1/orders/${orderId}/settle`)
      .set('Authorization', `Bearer ${hhi.cashierToken}`)
      .send({ clientSettleId: uuidv4(), payment: { method: 'CASH', tendered } });

  it('records a confirmed nota as an open transaction, lines named and priced as written', async () => {
    const res = await post(
      hhi,
      notaSale('2532', [
        { label: '1 M BESAR', amount: 130000 },
        { label: 'Setrika 2 kg', amount: 20000 },
      ]),
    );

    expect(res.status).toBe(201);
    expect(res.body.status).toBe('AWAITING_PAYMENT');
    expect(res.body.payments).toHaveLength(0);
    expect(res.body.subtotal).toBe(150000);
    expect(res.body.taxTotal).toBe(0);
    expect(res.body.grandTotal).toBe(150000);
    expect(res.body.externalOrderRef).toBe('2532');
    expect(res.body.customerName).toBe('Edward');

    const lines = await ctx.prisma.orderLine.findMany({
      where: { orderId: res.body.id },
      orderBy: { lineTotal: 'desc' },
    });
    // The paper's wording is the line's name, and its price is the line's real selling price.
    expect(lines.map((l) => l.productNameSnapshot)).toEqual(['1 M BESAR', 'Setrika 2 kg']);
    expect(lines.map((l) => l.unitPriceSnapshot)).toEqual([130000, 20000]);
    expect(lines.every((l) => Number(l.qty) === 1)).toBe(true);

    // It is waiting in the open bills list, where the existing settle flow picks it up.
    const open = await api()
      .get('/api/v1/orders/open')
      .query({ outletId: hhi.outletId })
      .set('Authorization', `Bearer ${hhi.cashierToken}`);
    expect(open.body.map((o: { id: string }) => o.id)).toContain(res.body.id);
  });

  it('keeps what the paper said but did not charge as the transaction note — never as money', async () => {
    const note = 'Tidak dihitung: A/J FREE; 31 pc\nKurang jelas: tanggal';
    const res = await post(hhi, {
      ...notaSale('2238', [{ label: '1 M BESAR', amount: 130000 }]),
      note,
      // A client total alongside it changes nothing: the note is text, the total is the lines.
      grandTotal: 1,
    });
    expect(res.status).toBe(201);
    expect(res.body.note).toBe(note);
    expect(res.body.grandTotal).toBe(130000);

    const stored = await ctx.prisma.order.findUnique({ where: { id: res.body.id } });
    expect(stored!.note).toBe(note);
    expect(stored!.grandTotal).toBe(130000);
  });

  it('refuses a note longer than 1000 characters', async () => {
    const res = await post(hhi, {
      ...notaSale(null, [{ label: 'Cuci', amount: 10000 }]),
      note: 'x'.repeat(1001),
    });
    expect(res.status).toBe(400);
  });

  it('settles through the existing settle path, and change comes from the server total', async () => {
    const bill = await post(hhi, notaSale('1900', [{ label: '1. M. KECIL', amount: 65000 }]));
    expect(bill.status).toBe(201);

    const paid = await settle(bill.body.id, 100000);
    expect(paid.status).toBeLessThan(300);
    expect(paid.body.status).toBe('COMPLETED');
    const charge = paid.body.payments.find((p: { direction: string }) => p.direction === 'CHARGE');
    expect(charge.amount).toBe(65000);
    expect(charge.change).toBe(35000);
  });

  describe('one nota, one sale', () => {
    it('refuses a nota number that is still open', async () => {
      const first = await post(hhi, notaSale('3001', [{ label: '1 M KECIL', amount: 60000 }]));
      expect(first.status).toBe(201);

      const again = await post(hhi, notaSale('3001', [{ label: '1 M KECIL', amount: 60000 }]));
      expect(again.status).toBe(409);
      expect(again.body.code).toBe('NOTA_ALREADY_RECORDED');
      expect(again.body.orderId).toBe(first.body.id);
    });

    it('refuses a nota number that is already paid', async () => {
      const first = await post(hhi, notaSale('3002', [{ label: '1 M BESAR', amount: 130000 }]));
      await settle(first.body.id, 130000);

      const again = await post(hhi, notaSale('3002', [{ label: '1 M BESAR', amount: 130000 }]));
      expect(again.status).toBe(409);
      expect(again.body.code).toBe('NOTA_ALREADY_RECORDED');
    });

    it('allows a nota again once its first transaction was cancelled', async () => {
      const first = await post(hhi, notaSale('3003', [{ label: '1 M KECIL', amount: 60000 }]));
      const cancelled = await api()
        .post(`/api/v1/orders/${first.body.id}/cancel`)
        .set('Authorization', `Bearer ${hhi.ownerToken}`)
        .send({ reason: 'salah baca' });
      expect(cancelled.status).toBeLessThan(300);

      const again = await post(hhi, notaSale('3003', [{ label: '1 M KECIL', amount: 65000 }]));
      expect(again.status).toBe(201);
    });

    it('treats a retried submit as the same sale, not a duplicate nota', async () => {
      // A double tap on "Tidak" reuses the reading's clientOrderId: idempotency answers first.
      const id = uuidv4();
      const first = await post(hhi, notaSale('3004', [{ label: 'Cuci', amount: 10000 }], id));
      const retry = await post(hhi, notaSale('3004', [{ label: 'Cuci', amount: 10000 }], id));
      expect(first.status).toBe(201);
      expect(retry.status).toBe(200);
      expect(retry.body.id).toBe(first.body.id);
    });

    it('does not deduplicate a nota whose number could not be read', async () => {
      const a = await post(hhi, notaSale(null, [{ label: 'Cuci', amount: 10000 }]));
      const b = await post(hhi, notaSale(null, [{ label: 'Cuci', amount: 10000 }]));
      expect(a.status).toBe(201);
      expect(b.status).toBe(201);
    });
  });

  describe('the gate', () => {
    it('refuses a label on a catalog item — it would rename that item in history', async () => {
      const res = await post(hhi, {
        clientOrderId: uuidv4(),
        outletId: hhi.outletId,
        type: 'RETAIL',
        lines: [{ variantId: hhi.variantRegularId, qty: 1, label: 'Kopi Mahal' }],
      });
      expect(res.status).toBe(400);
      expect(res.body.code).toBe('LABEL_ON_CATALOG_LINE');
    });

    it('refuses a label from an ordinary catalog merchant, and records nothing', async () => {
      const before = await ctx.prisma.order.count({ where: { merchantId: general.merchantId } });
      const res = await post(general, {
        clientOrderId: uuidv4(),
        outletId: general.outletId,
        type: 'DINE_IN',
        lines: [{ variantId: general.variantRegularId, qty: 1, label: 'Kopi Mahal' }],
        payment: { method: 'CASH', tendered: 50000 },
      });
      expect(res.status).toBe(403);
      expect(res.body.code).toBe('OPEN_AMOUNT_NOT_AVAILABLE');
      expect(await ctx.prisma.order.count({ where: { merchantId: general.merchantId } })).toBe(before);
    });

    it('still refuses an amount from an ordinary catalog merchant', async () => {
      const res = await post(general, {
        clientOrderId: uuidv4(),
        outletId: general.outletId,
        type: 'DINE_IN',
        lines: [{ variantId: general.variantRegularId, qty: 1, amount: 1 }],
        payment: { method: 'CASH', tendered: 50000 },
      });
      expect(res.status).toBe(403);
    });

    it('refuses a label longer than a nota line', async () => {
      const res = await post(
        hhi,
        notaSale(null, [{ label: 'x'.repeat(MAX_OPEN_AMOUNT_LABEL + 1), amount: 1000 }]),
      );
      expect(res.status).toBe(400);
    });

    it('refuses a priced nota line with no amount — it would otherwise sell for Rp 0', async () => {
      const res = await post(hhi, {
        clientOrderId: uuidv4(),
        outletId: hhi.outletId,
        type: 'RETAIL',
        lines: [{ variantId: hhi.openAmountVariantId, qty: 1, label: 'A/J FREE' }],
      });
      expect(res.status).toBe(400);
      expect(res.body.code).toBe('OPEN_AMOUNT_REQUIRED');
    });
  });

  it('publishes the type and the open-amount variant on /catalog, and no sentinel in the grid', async () => {
    const res = await api()
      .get('/api/v1/catalog')
      .query({ outletId: hhi.outletId })
      .set('Authorization', `Bearer ${hhi.cashierToken}`);
    expect(res.status).toBe(200);
    expect(res.body.businessType).toBe('HIGH_HUMAN_INTERACTION');
    expect(res.body.calculatorOnly).toBe(false);
    expect(res.body.openAmountVariantId).toBe(hhi.openAmountVariantId);
    expect(res.body.products.map((p: { name: string }) => p.name)).not.toContain('Nota');
  });
});
