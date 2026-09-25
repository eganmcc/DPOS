import request from 'supertest';
import { createTestApp, makeMerchant, cleanupMerchant, TestContext, MerchantFixture } from './fixtures';

/**
 * The demo login directory (GET /demo/directory).
 *
 * It is the one endpoint with no authentication, and it hands out PINs in PLAINTEXT so the app's
 * login picker can prefill them. That is defensible for seeded demo tills and for nothing else, so
 * what is tested here is the two ways it stops being a leak: it does not exist unless the
 * deployment says it is a demo one, and a PIN that gets rotated stops being published.
 */
describe('Demo login directory', () => {
  let ctx: TestContext;
  let fx: MerchantFixture;
  const original = process.env.DEMO_LOGINS;

  beforeAll(async () => {
    ctx = await createTestApp();
    fx = await makeMerchant(ctx);
  });
  afterAll(async () => {
    process.env.DEMO_LOGINS = original;
    await cleanupMerchant(ctx.prisma, fx.merchantId);
    await ctx.app.close();
  });

  const get = () => request(ctx.app.getHttpServer()).get('/api/v1/demo/directory');

  /** Make this fixture's cashier look like a seeded demo account. */
  const publishPin = (pin: string) =>
    ctx.prisma.staff.update({ where: { id: fx.cashierId }, data: { demoPin: pin } });

  it('does not exist unless the deployment says it is a demo one', async () => {
    process.env.DEMO_LOGINS = '0';
    await get().expect(404);
    delete process.env.DEMO_LOGINS;
    await get().expect(404);
  });

  it('lists a seeded demo login when the flag is on', async () => {
    process.env.DEMO_LOGINS = '1';
    await publishPin('9182');
    const res = await get().expect(200);
    const mine = (res.body as { merchantId: string; logins: { pin: string }[] }[]).find(
      (m) => m.merchantId === fx.merchantId,
    );
    expect(mine).toBeDefined();
    expect(mine!.logins.map((l) => l.pin)).toContain('9182');
  });

  it('stops publishing a PIN once it is rotated in the portal', async () => {
    // The published copy is plaintext and separate from the hash, so rotating the real PIN used to
    // leave the OLD one on a public endpoint for ever.
    process.env.DEMO_LOGINS = '1';
    await publishPin('9182');

    await request(ctx.app.getHttpServer())
      .post(`/api/v1/admin/staff/${fx.cashierId}/pin`)
      .set('Authorization', `Bearer ${fx.ownerToken}`)
      .send({ pin: '5566' })
      .expect(200);

    const res = await get().expect(200);
    const mine = (res.body as { merchantId: string; logins: { pin: string }[] }[]).find(
      (m) => m.merchantId === fx.merchantId,
    );
    const pins = mine?.logins.map((l) => l.pin) ?? [];
    expect(pins).not.toContain('9182');
    expect(pins).not.toContain('5566');
  });
});
