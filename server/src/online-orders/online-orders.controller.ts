import {
  Body,
  Controller,
  Get,
  Param,
  ParseUUIDPipe,
  Post,
  Query,
  Res,
  UseGuards,
} from '@nestjs/common';
import { Response } from 'express';
import { AuthGuard } from '../auth/auth.guard';
import { RolesGuard } from '../auth/roles.guard';
import { CurrentUser } from '../auth/current-user.decorator';
import { AuthUser } from '../auth/auth.types';
import { OnlineOrdersService } from './online-orders.service';
import { OnlineOrdersQuery, SimulateOnlineOrderDto } from './dto';
import { mapOrder } from '../orders/order.mapper';

@Controller('online-orders')
@UseGuards(AuthGuard, RolesGuard)
export class OnlineOrdersController {
  constructor(private readonly online: OnlineOrdersService) {}

  /** Online-delivery orders for an outlet (NEW first), scoped to the caller's merchant. */
  @Get()
  async list(@CurrentUser() user: AuthUser, @Query() query: OnlineOrdersQuery) {
    const orders = await this.online.findOnline(user.merchantId, query.outletId, query.status);
    return orders.map(mapOrder);
  }

  /** Cashier acknowledges a new online order (NEW → ACCEPTED). Idempotent. */
  @Post(':id/accept')
  async accept(@CurrentUser() user: AuthUser, @Param('id', ParseUUIDPipe) id: string) {
    const order = await this.online.accept(user.merchantId, id);
    return mapOrder(order);
  }

  /** Mark fulfilled (→ COMPLETED) — drops it from the active queue into history. */
  @Post(':id/complete')
  async complete(@CurrentUser() user: AuthUser, @Param('id', ParseUUIDPipe) id: string) {
    const order = await this.online.complete(user.merchantId, id);
    return mapOrder(order);
  }

  /**
   * DEMO ONLY: fabricate a random online order for the outlet (random vendor + random
   * in-stock items) and ingest it. Real provider webhooks replace this endpoint later.
   */
  @Post('simulate')
  async simulate(
    @CurrentUser() user: AuthUser,
    @Body() dto: SimulateOnlineOrderDto,
    @Res({ passthrough: true }) res: Response,
  ) {
    const order = await this.online.simulate(user.merchantId, dto.outletId, user.staffId);
    res.status(201);
    return mapOrder(order);
  }
}
