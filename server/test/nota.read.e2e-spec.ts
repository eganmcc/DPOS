import request from 'supertest';
import {
  createTestApp,
  makeMerchant,
  cleanupMerchant,
  TestContext,
  MerchantFixture,
} from './fixtures';

/**
 * POST /nota/read — photograph a nota, get back what it says.
 *
 * Runs against the STUB reader. That is enforced here rather than assumed: a developer's
 * local .env may well hold a real ANTHROPIC_API_KEY, and the integrity suite must never make a
 * paid external call.
 */
describe('Nota reader', () => {
  let ctx: TestContext;
  let fx: MerchantFixture;

  beforeAll(async () => {
    process.env.NOTA_VISION_PROVIDER = 'stub';
    ctx = await createTestApp();
    fx = await makeMerchant(ctx);
  });
  afterAll(async () => {
    await cleanupMerchant(ctx.prisma, fx.merchantId);
    await ctx.app.close();
  });

  const api = () => request(ctx.app.getHttpServer());

  /** A byte buffer that starts like a real JPEG; `size` lets a test vary the content. */
  const jpeg = (size = 2048) => {
    const b = Buffer.alloc(size, 0x20);
    b[0] = 0xff;
    b[1] = 0xd8;
    b[2] = 0xff;
    b[3] = 0xe0;
    return b;
  };

  const png = () => {
    const b = Buffer.alloc(1024, 0x20);
    Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]).copy(b);
    return b;
  };

  it('reads a photo and returns the extraction with its provenance', async () => {
    const res = await api()
      .post('/api/v1/nota/read')
      .set('Authorization', `Bearer ${fx.cashierToken}`)
      .attach('file', jpeg(), { filename: 'nota.jpg', contentType: 'image/jpeg' })
      .expect(200);

    expect(res.body.model).toBe('stub');
    expect(typeof res.body.latencyMs).toBe('number');
    expect(res.body.notaDate).toBe('2026-07-11');
    expect(res.body.total).toBe(65000);
    expect(res.body.items).toHaveLength(1);
    // Item text is returned verbatim — shorthand intact, not expanded into a guessed name.
    expect(res.body.items[0].rawText).toBe('1. M. KECIL');
    expect(Array.isArray(res.body.unclear)).toBe(true);
  });

  it('answers from the bytes it was sent, not a constant', async () => {
    const a = await api()
      .post('/api/v1/nota/read')
      .set('Authorization', `Bearer ${fx.cashierToken}`)
      .attach('file', jpeg(2048), { filename: 'a.jpg', contentType: 'image/jpeg' })
      .expect(200);
    const b = await api()
      .post('/api/v1/nota/read')
      .set('Authorization', `Bearer ${fx.cashierToken}`)
      .attach('file', jpeg(2049), { filename: 'b.jpg', contentType: 'image/jpeg' })
      .expect(200);
    expect(a.body.notaNumber).not.toBe(b.body.notaNumber);
  });

  it('accepts PNG as well as JPEG', async () => {
    await api()
      .post('/api/v1/nota/read')
      .set('Authorization', `Bearer ${fx.cashierToken}`)
      .attach('file', png(), { filename: 'nota.png', contentType: 'image/png' })
      .expect(200);
  });

  it('refuses a file whose bytes are not an image, whatever it claims to be', async () => {
    // Named .jpg and labelled image/jpeg, but it is plain text. The declared type is a claim;
    // the magic bytes are the evidence.
    const res = await api()
      .post('/api/v1/nota/read')
      .set('Authorization', `Bearer ${fx.cashierToken}`)
      .attach('file', Buffer.from('not really a photo, just text '.repeat(10)), {
        filename: 'nota.jpg',
        contentType: 'image/jpeg',
      })
      .expect(415);
    expect(res.body.code).toBe('NOTA_UNSUPPORTED_IMAGE');
  });

  it('refuses a request with no photo attached', async () => {
    const res = await api()
      .post('/api/v1/nota/read')
      .set('Authorization', `Bearer ${fx.cashierToken}`)
      .expect(400);
    expect(res.body.code).toBe('NOTA_NO_IMAGE');
  });

  it('refuses an oversized upload', async () => {
    await api()
      .post('/api/v1/nota/read')
      .set('Authorization', `Bearer ${fx.cashierToken}`)
      .attach('file', jpeg(6 * 1024 * 1024 + 1), { filename: 'huge.jpg', contentType: 'image/jpeg' })
      .expect(413);
  });

  it('requires a signed-in staff member', async () => {
    await api()
      .post('/api/v1/nota/read')
      .attach('file', jpeg(), { filename: 'nota.jpg', contentType: 'image/jpeg' })
      .expect(401);
  });

  // ?model= picks which model reads the slip, and therefore what the read costs. It is an
  // evaluation affordance, so it is fenced on both sides: who may ask, and what they may ask for.
  describe('?model= override', () => {
    it('refuses a cashier — choosing the model chooses the bill', async () => {
      const res = await api()
        .post('/api/v1/nota/read?model=claude-haiku-4-5-20251001')
        .set('Authorization', `Bearer ${fx.cashierToken}`)
        .attach('file', jpeg(), { filename: 'nota.jpg', contentType: 'image/jpeg' })
        .expect(403);
      expect(res.body.code).toBe('NOTA_MODEL_OVERRIDE_FORBIDDEN');
    });

    it('refuses a model outside the allowlist, even from an owner', async () => {
      const res = await api()
        .post('/api/v1/nota/read?model=some-other-model')
        .set('Authorization', `Bearer ${fx.ownerToken}`)
        .attach('file', jpeg(), { filename: 'nota.jpg', contentType: 'image/jpeg' })
        .expect(400);
      expect(res.body.code).toBe('NOTA_MODEL_NOT_ALLOWED');
    });

    it('lets an owner name an allowlisted model', async () => {
      // The stub ignores the override, but the request must be accepted and the reading must come
      // back reported under the model that was asked for, or a comparison would be meaningless.
      const res = await api()
        .post('/api/v1/nota/read?model=claude-sonnet-5')
        .set('Authorization', `Bearer ${fx.ownerToken}`)
        .attach('file', jpeg(), { filename: 'nota.jpg', contentType: 'image/jpeg' })
        .expect(200);
      expect(res.body.model).toBe('claude-sonnet-5');
    });
  });
});
