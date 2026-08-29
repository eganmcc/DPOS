import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { PrismaModule } from './prisma/prisma.module';
import { AuthModule } from './auth/auth.module';
import { CatalogModule } from './catalog/catalog.module';
import { OrdersModule } from './orders/orders.module';
import { OnlineOrdersModule } from './online-orders/online-orders.module';
import { AdminModule } from './admin/admin.module';
import { DemoModule } from './demo/demo.module';
import { VersionController } from './version.controller';

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true }),
    PrismaModule,
    AuthModule,
    CatalogModule,
    OrdersModule,
    OnlineOrdersModule,
    AdminModule,
    DemoModule,
  ],
  controllers: [VersionController],
})
export class AppModule {}
