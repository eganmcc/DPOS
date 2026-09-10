import { Module } from '@nestjs/common';
import { PaymentsService } from './payments.service';
import { CashProvider } from './providers/cash.provider';
import { SimulatedQrisProvider } from './providers/simulated-qris.provider';
import { OnlineProvider } from './providers/online.provider';
import { SimulatedEdcProvider } from './providers/simulated-edc.provider';
import { SimulatedEwalletProvider } from './providers/simulated-ewallet.provider';

@Module({
  providers: [
    PaymentsService,
    CashProvider,
    SimulatedQrisProvider,
    OnlineProvider,
    SimulatedEdcProvider,
    SimulatedEwalletProvider,
  ],
  exports: [PaymentsService],
})
export class PaymentsModule {}
