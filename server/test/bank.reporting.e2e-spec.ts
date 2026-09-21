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
