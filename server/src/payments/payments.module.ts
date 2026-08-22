import { Module } from '@nestjs/common';
import { PaymentsService } from './payments.service';
import { CashProvider } from './providers/cash.provider';
import { SimulatedQrisProvider } from './providers/simulated-qris.provider';

@Module({
  providers: [PaymentsService, CashProvider, SimulatedQrisProvider],
  exports: [PaymentsService],
})
export class PaymentsModule {}
