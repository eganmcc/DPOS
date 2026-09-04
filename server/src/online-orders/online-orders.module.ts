import { Module } from '@nestjs/common';
import { PaymentsModule } from '../payments/payments.module';
import { OnlineOrdersService } from './online-orders.service';
import { OnlineOrdersController } from './online-orders.controller';

@Module({
  imports: [PaymentsModule],
  providers: [OnlineOrdersService],
  controllers: [OnlineOrdersController],
  exports: [OnlineOrdersService],
})
export class OnlineOrdersModule {}
