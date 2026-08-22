import { Module } from '@nestjs/common';
import { PaymentsModule } from '../payments/payments.module';
import { OrdersService } from './orders.service';
import { VoidService } from './void.service';
import { OrdersController } from './orders.controller';

@Module({
  imports: [PaymentsModule],
  providers: [OrdersService, VoidService],
  controllers: [OrdersController],
  exports: [OrdersService, VoidService],
})
export class OrdersModule {}
