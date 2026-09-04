import { Module } from '@nestjs/common';
import { PaymentsService } from './payments.service';
import { CashProvider } from './providers/cash.provider';
import { SimulatedQrisProvider } from './providers/simulated-qris.provider';
import { OnlineProvider } from './providers/online.provider';

@Module({
  providers: [PaymentsService, CashProvider, SimulatedQrisProvider, OnlineProvider],
  exports: [PaymentsService],
})
export class PaymentsModule {}
