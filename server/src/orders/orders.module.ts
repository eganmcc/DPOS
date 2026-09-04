import { Module } from '@nestjs/common';
import { PaymentsModule } from '../payments/payments.module';
import { OrdersService } from './orders.service';
import { VoidService } from './void.service';
import { RefundService } from './refund.service';
import { OrdersController } from './orders.controller';

@Module({
  imports: [PaymentsModule],
  providers: [OrdersService, VoidService, RefundService],
  controllers: [OrdersController],
  exports: [OrdersService, VoidService, RefundService],
})
export class OrdersModule {}
