import request from 'supertest';
import { v4 as uuidv4 } from 'uuid';
import { createTestApp, makeMerchant, cleanupMerchant, TestContext, MerchantFixture } from './fixtures';

/**
 * Bank reporting (specs/011-bank-reporting).
 *
 * The reports themselves are read-only, so most of this suite is about the two things that can go
 * wrong when a bank is the reader: showing one merchant's takings to another, and exporting a
 * merchant's figures they never agreed to share.
 */
describe('Bank reporting', () => {
  let ctx: TestContext;
  let fx: MerchantFixture;
  let other: MerchantFixture;

  beforeAll(async () => {
    ctx = await createTestApp();
    fx = await makeMerchant(ctx);
    other = await makeMerchant(ctx);
  });
  afterAll(async () => {
    for (const m of [fx, other]) await cleanupMerchant(ctx.prisma, m.merchantId);
    await ctx.app.close();
  });

  const api = () => request(ctx.app.getHttpServer());
  const get = (path: string, token: string) =>
    api().get(`/api/v1/admin/bank/${path}`).set('Authorization', `Bearer ${token}`);

  /** One cash sale and one QRIS sale, so there is something to report on. */
  const sell = async (f: MerchantFixture, method: string, amount = 1) =>
    api()
      .post('/api/v1/orders')
      .set('Authorization', `Bearer ${f.cashierToken}`)
      .send({
        clientOrderId: uuidv4(),
        outletId: f.outletId,
        type: 'TAKEAWAY',
        lines: [{ variantId: f.variantRegularId, qty: amount }],
        payment: { method, tendered: 1000000 },
      });

  const consent = (f: MerchantFixture) =>
    ctx.prisma.merchant.update({
      where: { id: f.merchantId },
      data: { dataConsentAt: new Date(), dataConsentVersion: 'test-v1', dataConsentRevokedAt: null },
    });

  describe('consent gates the credit data', () => {
    it('refuses the credit profile until the merchant has agreed to share', async () => {
      await ctx.prisma.merchant.update({
        where: { id: fx.merchantId },
        data: { dataConsentAt: null, dataConsentRevokedAt: null },
      });
      const res = await get('credit-profile', fx.ownerToken);
      expect(res.status).toBe(403);
      expect(res.body.code).toBe('DATA_CONSENT_REQUIRED');
    });

    it('allows it once consent is recorded', async () => {
      await consent(fx);
      const res = await get('credit-profile', fx.ownerToken);
      expect(res.status).toBe(200);
      expect(res.body.series).toBeDefined();
    });

    it('refuses again after consent is withdrawn — it is revocable, not a one-time tick', async () => {
      await ctx.prisma.merchant.update({
        where: { id: fx.merchantId },
        data: { dataConsentRevokedAt: new Date() },
      });
      const res = await get('credit-profile', fx.ownerToken);
      expect(res.status).toBe(403);
      await consent(fx); // restore for the rest of the suite
    });
  });

  describe('the activation funnel cannot see across the tenancy', () => {
    it("shows only the caller's own merchant without the bank key", async () => {
      await ctx.prisma.merchant.updateMany({
        where: { id: { in: [fx.merchantId, other.merchantId] } },
        data: { onboardedAt: new Date(), bankBranch: 'KCP Test' },
      });
      const res = await get('activation', fx.ownerToken);
      expect(res.status).toBe(200);
      // Both merchants are onboarded and in the same branch; an OWNER token must still see one.
      expect(res.body.merchants).toHaveLength(1);
      expect(res.body.merchants[0].merchantId).toBe(fx.merchantId);
    });

    it('a wrong key is no key', async () => {
      process.env.BANK_PORTFOLIO_KEY = 'right-key';
      const res = await api()
        .get('/api/v1/admin/bank/activation')
        .set('Authorization', `Bearer ${fx.ownerToken}`)
        .set('x-bank-key', 'wrong-key');
      expect(res.body.merchants).toHaveLength(1);
      delete process.env.BANK_PORTFOLIO_KEY;
    });
  });

  describe('reconciliation', () => {
    it('matches what we recorded against what the acquirer settled', async () => {
      const sale = await sell(fx, 'QRIS_SIMULATED');
      expect(sale.status).toBe(201);
      const day = new Date().toISOString().slice(0, 10);

      await api()
        .post('/api/v1/admin/bank/settlement')
        .set('Authorization', `Bearer ${fx.ownerToken}`)
        .send({
          rows: [
            {
              settledOn: day,
              method: 'QRIS',
              grossAmount: sale.body.grandTotal,
              feeAmount: 0,
              netAmount: sale.body.grandTotal,
              txnCount: 1,
              externalRef: `test-${uuidv4()}`,
            },
          ],
        })
        .expect(201);

      const res = await get(`reconciliation?from=${day}&to=${day}`, fx.ownerToken);
      expect(res.status).toBe(200);
      const qris = res.body.lines.find((l: { rail: string }) => l.rail === 'QRIS');
      expect(qris.status).toBe('MATCHED');
      expect(res.body.summary.matchRateBps).toBe(10000);
    });

    it('reports a shortfall rather than quietly absorbing it', async () => {
      const day = new Date().toISOString().slice(0, 10);
      await sell(fx, 'CARD_DEBIT');
      await api()
        .post('/api/v1/admin/bank/settlement')
        .set('Authorization', `Bearer ${fx.ownerToken}`)
        .send({
          rows: [
            {
              settledOn: day,
              method: 'CARD',
              grossAmount: 1, // the acquirer says it settled almost nothing
              netAmount: 1,
              txnCount: 1,
              externalRef: `test-short-${uuidv4()}`,
            },
          ],
        })
        .expect(201);

      const res = await get(`reconciliation?from=${day}&to=${day}`, fx.ownerToken);
      const card = res.body.lines.find((l: { rail: string }) => l.rail === 'CARD');
      expect(card.status).toBe('AMOUNT_DIFFERS');
      expect(card.difference).toBeGreaterThan(0);
      // Both sides survive: the report never edits the bank's number to fit ours.
      expect(card.dposAmount).toBeGreaterThan(card.settledAmount);
    });

    it('a re-sent settlement file updates rather than duplicates', async () => {
      const day = new Date().toISOString().slice(0, 10);
      const ref = `test-idem-${uuidv4()}`;
      const row = {
        settledOn: day,
        method: 'QRIS',
        grossAmount: 5000,
        netAmount: 5000,
        txnCount: 1,
        externalRef: ref,
      };
      const send = () =>
        api()
          .post('/api/v1/admin/bank/settlement')
          .set('Authorization', `Bearer ${fx.ownerToken}`)
          .send({ rows: [row] });
      await send();
      await send();
      const count = await ctx.prisma.settlementRecord.count({
        where: { merchantId: fx.merchantId, externalRef: ref },
      });
      expect(count).toBe(1);
    });

    it('cash never appears — it never reached an acquirer', async () => {
      const day = new Date().toISOString().slice(0, 10);
      await sell(fx, 'CASH');
      const res = await get(`reconciliation?from=${day}&to=${day}`, fx.ownerToken);
      expect(res.body.lines.every((l: { rail: string }) => l.rail !== 'CASH')).toBe(true);
    });
  });

  describe('the credit figures', () => {
    it('counts trading days and the cash share, and carries months of history', async () => {
      const res = await get('credit-profile', fx.ownerToken);
      expect(res.status).toBe(200);
      const month = res.body.series[res.body.series.length - 1];
      expect(month.tradingDays).toBeGreaterThanOrEqual(1);
      expect(month.cashShareBps).toBeGreaterThan(0);
      expect(res.body.summary.monthsOfHistory).toBeGreaterThanOrEqual(1);
    });

    it('a merchant with no catalogue reports NO margin rather than a zero', async () => {
      // A calculator merchant has no cost price by definition. Sending 0 would read as a 100%
      // margin to a scorecard that does not know the difference.
      const calc = await makeMerchant(ctx, { calculatorOnly: true, businessSize: 'UMI' as never });
      await ctx.prisma.merchant.update({
        where: { id: calc.merchantId },
        data: { dataConsentAt: new Date(), dataConsentVersion: 'test-v1' },
      });
      await api()
        .post('/api/v1/orders')
        .set('Authorization', `Bearer ${calc.cashierToken}`)
        .send({
          clientOrderId: uuidv4(),
          outletId: calc.outletId,
          type: 'RETAIL',
          lines: [{ variantId: calc.openAmountVariantId, qty: 1, amount: 25000 }],
          payment: { method: 'CASH', tendered: 25000 },
        })
        .expect(201);

      const res = await get('credit-profile', calc.ownerToken);
      expect(res.body.merchant.sellsFromCatalogue).toBe(false);
      const month = res.body.series[res.body.series.length - 1];
      expect(month.grossProfit).toBeNull();
      expect(month.grossMarginBps).toBeNull();
      await cleanupMerchant(ctx.prisma, calc.merchantId);
    });
  });

  describe('laporan laba rugi', () => {
    it('derives laba bersih from the merchant’s own beban usaha', async () => {
      const day = new Date().toISOString().slice(0, 10);
      const res = await get(`profit-loss?from=${day}&to=${day}&expenses=10000`, fx.ownerToken);
      expect(res.status).toBe(200);
      expect(res.body.labaKotor).toBe(res.body.pendapatan - res.body.hpp);
      expect(res.body.labaBersih).toBe(res.body.labaKotor - 10000);
      expect(res.body.bebanUsaha).toBe(10000);
    });
  });

  describe('data integrity', () => {
    it('counts voids and names who approved them', async () => {
      const sale = await sell(fx, 'CASH');
      await api()
        .post(`/api/v1/orders/${sale.body.id}/void`)
        .set('Authorization', `Bearer ${fx.cashierToken}`)
        .send({ reason: 'test', clientVoidId: uuidv4(), approverPin: '4321' })
        .expect((r) => expect(r.status).toBeLessThan(300));

      const res = await get('integrity', fx.ownerToken);
      expect(res.status).toBe(200);
      expect(res.body.voids.count).toBeGreaterThanOrEqual(1);
      expect(res.body.voids.byApprover.length).toBeGreaterThanOrEqual(1);
      // The claims the report stands behind are stated, not implied.
      expect(res.body.assurances.correctionsAppendOnly).toBe(true);
      expect(res.body.assurances.dataResidency).toContain('Jakarta');
    });
  });
});

/**
 * Transaction-level and journal reporting.
 *
 * The property worth testing hardest is the general journal: debits must equal credits, every day,
 * or an accountant cannot post it and would be right not to trust the rest.
 */
describe('Journal reporting', () => {
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
  const get = (path: string) =>
    api().get(`/api/v1/admin/journal/${path}`).set('Authorization', `Bearer ${fx.ownerToken}`);

  const sell = (method = 'CASH', qty = 1) =>
    api()
      .post('/api/v1/orders')
      .set('Authorization', `Bearer ${fx.cashierToken}`)
      .send({
        clientOrderId: uuidv4(),
        outletId: fx.outletId,
        type: 'TAKEAWAY',
        lines: [{ variantId: fx.variantRegularId, qty }],
        payment: { method, tendered: 1000000 },
      });

  it('lists transactions with what was sold and how it was paid', async () => {
    const sale = await sell('CASH');
    expect(sale.status).toBe(201);
    const res = await get('transactions');
    expect(res.status).toBe(200);
    const row = res.body.rows.find((r: { id: string }) => r.id === sale.body.id);
    expect(row).toBeDefined();
    expect(row.methods).toContain('CASH');
    expect(row.total).toBe(sale.body.grandTotal);
    expect(row.description).toContain('×');
  });

  it('keeps a voided sale IN the journal, labelled — not filtered out of it', async () => {
    const sale = await sell('CASH');
    await api()
      .post(`/api/v1/orders/${sale.body.id}/void`)
      .set('Authorization', `Bearer ${fx.cashierToken}`)
      .send({ reason: 'salah input', clientVoidId: uuidv4(), approverPin: '4321' });

    const res = await get('transactions');
    const row = res.body.rows.find((r: { id: string }) => r.id === sale.body.id);
    expect(row.status).toBe('VOIDED');
    expect(row.voidReason).toBe('salah input');
  });

  it('the daily recap banks the live sales and counts the voided ones separately', async () => {
    const res = await get('daily');
    expect(res.status).toBe(200);
    const today = res.body.rows[0];
    expect(today.orders).toBeGreaterThanOrEqual(1);
    expect(today.voided).toBeGreaterThanOrEqual(1);
    // A voided sale contributes to neither the takings nor the drawer.
    expect(today.gross).toBeGreaterThan(0);
    expect(today.cash + today.nonCash).toBe(today.gross);
  });

  it('the corrections journal names the reason and the approver', async () => {
    const res = await get('corrections');
    expect(res.status).toBe(200);
    const voided = res.body.rows.find((r: { kind: string }) => r.kind === 'VOID');
    expect(voided.reason).toBe('salah input');
    expect(voided.approvedBy).toBeTruthy();
    expect(voided.selfApproved).toBe(false);
  });

  it('the tax recap carries the rate it was charged at', async () => {
    const res = await get('tax');
    expect(res.status).toBe(200);
    expect(res.body.totals.tax).toBeGreaterThan(0);
    expect(res.body.rateBps).toBeGreaterThan(0);
    expect(res.body.label).toBeTruthy();
  });

  describe('the general journal', () => {
    it('balances — debits equal credits, every day', async () => {
      await sell('QRIS_SIMULATED');
      const res = await get('general');
      expect(res.status).toBe(200);
      expect(res.body.entries.length).toBeGreaterThan(0);
      for (const e of res.body.entries) {
        expect(e.debit).toBe(e.credit);
        expect(e.balanced).toBe(true);
      }
      expect(res.body.totals.unbalancedDays).toBe(0);
      expect(res.body.totals.debit).toBe(res.body.totals.credit);
    });

    it('posts cash and non-cash to different accounts', async () => {
      const res = await get('general');
      const today = res.body.entries[0];
      const accounts = today.postings.map((p: { account: string }) => p.account);
      expect(accounts).toContain('Kas');
      expect(accounts).toContain('Bank / Piutang Penyelenggara');
      expect(accounts).toContain('Pendapatan Penjualan');
      expect(accounts).toContain('Pajak Terutang (PB1/PPN)');
    });

    it('a voided sale is posted nowhere at all', async () => {
      const before = await get('general');
      const beforeDebit = before.body.totals.debit;
      const sale = await sell('CASH');
      await api()
        .post(`/api/v1/orders/${sale.body.id}/void`)
        .set('Authorization', `Bearer ${fx.cashierToken}`)
        .send({ reason: 'test', clientVoidId: uuidv4(), approverPin: '4321' });
      const after = await get('general');
      expect(after.body.totals.debit).toBe(beforeDebit);
    });
  });

  /**
   * The date pickers on every report screen. These are filters over money, so "returned 200" is
   * not the test — what is in and out of the window is.
   */
  describe('the date filter', () => {
    const today = () => new Date().toISOString().slice(0, 10);
    const dayBefore = (n: number) =>
      new Date(Date.now() - n * 86400000).toISOString().slice(0, 10);

    it('a malformed date is refused, not handed to the database', async () => {
      // transactions/ took its query as an intersection type, which left the ValidationPipe no
      // class to instantiate: nothing was checked and `new Date('10-09-2026')` reached Prisma.
      for (const ep of ['transactions', 'daily', 'corrections', 'tax', 'general']) {
        const res = await get(`${ep}?from=10-09-2026`);
        expect([ep, res.status]).toEqual([ep, 400]);
      }
    });

    it('keeps a sale inside its own day and out of every other', async () => {
      await sell('CASH');
      const inside = await get(`transactions?from=${today()}&to=${today()}`);
      expect(inside.body.total).toBeGreaterThan(0);
      expect(inside.body.range).toEqual({ from: today(), to: today() });

      const before = await get(`transactions?from=${dayBefore(30)}&to=${dayBefore(20)}`);
      expect(before.body.total).toBe(0);
    });

    it('a range asked backwards is swapped, not answered with nothing', async () => {
      await sell('CASH');
      // A picker fires on every change, so "to" gets set before "from" all the time. Returning
      // zero rows there reads as "this merchant had no sales".
      const res = await get(`transactions?from=${today()}&to=${dayBefore(3)}`);
      expect(res.body.range).toEqual({ from: dayBefore(3), to: today() });
      expect(res.body.total).toBeGreaterThan(0);
    });

    it('paging is validated and honoured', async () => {
      await sell('CASH');
      await sell('CASH');
      const page = await get('transactions?limit=1&offset=0');
      expect(page.body.limit).toBe(1);
      expect(page.body.rows).toHaveLength(1);
      const next = await get('transactions?limit=1&offset=1');
      expect(next.body.rows[0].id).not.toBe(page.body.rows[0].id);
      await get('transactions?limit=0').expect(400);
      await get('transactions?limit=abc').expect(400);
    });

    it('the same window gives every report the same day', async () => {
      await sell('CASH');
      const [daily, tax, ledger] = await Promise.all([
        get(`daily?from=${today()}&to=${today()}`),
        get(`tax?from=${today()}&to=${today()}`),
        get(`general?from=${today()}&to=${today()}`),
      ]);
      expect(daily.body.rows.map((r: { day: string }) => r.day)).toEqual([today()]);
      expect(tax.body.rows.map((r: { day: string }) => r.day)).toEqual([today()]);
      expect(ledger.body.entries.map((e: { day: string }) => e.day)).toEqual([today()]);
    });
  });
});
