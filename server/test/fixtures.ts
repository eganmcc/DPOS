import { INestApplication, ValidationPipe } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { Test } from '@nestjs/testing';
import { v4 as uuidv4 } from 'uuid';
import { AppModule } from '../src/app.module';
import { PrismaService } from '../src/prisma/prisma.service';
import { StaffRole } from '@prisma/client';

export interface TestContext {
  app: INestApplication;
  prisma: PrismaService;
  jwt: JwtService;
}

export async function createTestApp(): Promise<TestContext> {
  const moduleRef = await Test.createTestingModule({ imports: [AppModule] }).compile();
  const app = moduleRef.createNestApplication();
  app.setGlobalPrefix('api/v1');
  app.useGlobalPipes(new ValidationPipe({ whitelist: true, transform: true }));
  await app.init();
  return {
    app,
    prisma: app.get(PrismaService),
    jwt: app.get(JwtService),
  };
}

export interface MerchantFixture {
  merchantId: string;
  outletId: string;
  cashierId: string;
  ownerId: string;
  cashierToken: string;
  ownerToken: string;
  variantRegularId: string; // tracked, price 18000
  variantLargeId: string; // tracked, price 23000
  modifierExtraShotId: string; // +5000
}

/** Creates an isolated merchant with catalog + tax rule + stock, returns ids and JWTs. */
export async function makeMerchant(ctx: TestContext): Promise<MerchantFixture> {
  const { prisma, jwt } = ctx;
  const merchant = await prisma.merchant.create({ data: { name: `Test ${uuidv4()}` } });
  const outlet = await prisma.outlet.create({
    data: { merchantId: merchant.id, name: 'Test Outlet' },
  });
  const cashier = await prisma.staff.create({
    data: { merchantId: merchant.id, name: 'Cashier', role: StaffRole.CASHIER, pinHash: 'x' },
  });
  const owner = await prisma.staff.create({
    data: { merchantId: merchant.id, name: 'Owner', role: StaffRole.OWNER, pinHash: 'x' },
  });
  await prisma.taxRule.create({
    data: {
      merchantId: merchant.id,
      outletId: outlet.id,
      label: 'PBJT',
      rateBps: 1000,
      serviceChargeBps: 500,
      serviceLabel: 'Service',
    },
  });

  const product = await prisma.product.create({
    data: {
      merchantId: merchant.id,
      categoryId: (
        await prisma.category.create({ data: { merchantId: merchant.id, name: 'Cat' } })
      ).id,
      name: 'Kopi Susu',
      variants: {
        create: [
          { name: 'Regular', price: 18000, isDefault: true, trackInventory: true },
          { name: 'Large', price: 23000, trackInventory: true },
        ],
      },
      modifierGroups: {
        create: [
          { name: 'Sugar', modifiers: { create: [{ name: 'Extra shot', priceDelta: 5000 }] } },
        ],
      },
    },
    include: { variants: true, modifierGroups: { include: { modifiers: true } } },
  });
  const regular = product.variants.find((v) => v.name === 'Regular')!;
  const large = product.variants.find((v) => v.name === 'Large')!;
  const extraShot = product.modifierGroups[0].modifiers[0];

  for (const v of product.variants) {
    await prisma.inventoryStock.create({
      data: { merchantId: merchant.id, outletId: outlet.id, variantId: v.id, quantityOnHand: 100 },
    });
  }

  const sign = (staffId: string, role: StaffRole) =>
    jwt.sign({ sub: staffId, merchantId: merchant.id, role });

  return {
    merchantId: merchant.id,
    outletId: outlet.id,
    cashierId: cashier.id,
    ownerId: owner.id,
    cashierToken: sign(cashier.id, StaffRole.CASHIER),
    ownerToken: sign(owner.id, StaffRole.OWNER),
    variantRegularId: regular.id,
    variantLargeId: large.id,
    modifierExtraShotId: extraShot.id,
  };
}

/** Deletes all rows for a merchant in FK-safe order (test cleanup). */
export async function cleanupMerchant(prisma: PrismaService, merchantId: string): Promise<void> {
  const orders = await prisma.order.findMany({ where: { merchantId }, select: { id: true } });
  const orderIds = orders.map((o) => o.id);
  await prisma.payment.deleteMany({ where: { merchantId } });
  await prisma.orderDiscount.deleteMany({ where: { orderId: { in: orderIds } } });
  await prisma.orderLine.deleteMany({ where: { orderId: { in: orderIds } } });
  await prisma.orderVoid.deleteMany({ where: { merchantId } });
  await prisma.order.deleteMany({ where: { merchantId } });
  await prisma.inventoryMovement.deleteMany({ where: { merchantId } });
  await prisma.inventoryStock.deleteMany({ where: { merchantId } });
  const groups = await prisma.modifierGroup.findMany({
    where: { product: { merchantId } },
    select: { id: true },
  });
  await prisma.modifier.deleteMany({ where: { modifierGroupId: { in: groups.map((g) => g.id) } } });
  await prisma.modifierGroup.deleteMany({ where: { product: { merchantId } } });
  await prisma.productOutlet.deleteMany({ where: { merchantId } });
  await prisma.productVariant.deleteMany({ where: { product: { merchantId } } });
  await prisma.product.deleteMany({ where: { merchantId } });
  await prisma.category.deleteMany({ where: { merchantId } });
  await prisma.taxRule.deleteMany({ where: { merchantId } });
  await prisma.auditLog.deleteMany({ where: { merchantId } });
  await prisma.staff.deleteMany({ where: { merchantId } });
  await prisma.outlet.deleteMany({ where: { merchantId } });
  await prisma.merchant.delete({ where: { id: merchantId } });
}
