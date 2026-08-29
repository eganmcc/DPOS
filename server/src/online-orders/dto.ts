import { IsEnum, IsOptional, IsUUID } from 'class-validator';
import { OnlineOrderStatus } from '@prisma/client';

export class OnlineOrdersQuery {
  @IsUUID()
  outletId!: string;

  @IsOptional()
  @IsEnum(OnlineOrderStatus)
  status?: OnlineOrderStatus;
}

/** DEMO: inject a random online order into the given outlet. */
export class SimulateOnlineOrderDto {
  @IsUUID()
  outletId!: string;
}
