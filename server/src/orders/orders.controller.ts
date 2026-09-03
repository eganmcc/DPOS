import {
  Body,
  Controller,
  Get,
  HttpCode,
  NotFoundException,
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
import { OrdersService } from './orders.service';
import { VoidService } from './void.service';
import { RefundService } from './refund.service';
import {
  OpenOrdersQuery,
  OrderHistoryQuery,
  OrderReviseDto,
  OrderSubmitDto,
  RefundOrderDto,
  SettleOrderDto,
  VoidOrderDto,
} from './dto';
import { mapOrder } from './order.mapper';

@Controller('orders')
@UseGuards(AuthGuard, RolesGuard)
export class OrdersController {
  constructor(
    private readonly orders: OrdersService,
    private readonly voids: VoidService,
    private readonly refunds: RefundService,
  ) {}

  @Post()
  async submit(
    @CurrentUser() user: AuthUser,
    @Body() dto: OrderSubmitDto,
    @Res({ passthrough: true }) res: Response,
  ) {
    const { order, replay } = await this.orders.checkout(user, dto);
    res.status(replay ? 200 : 201); // 200 = idempotent replay, 201 = new sale
    return mapOrder(order);
  }

  /** Transaction history for an outlet (newest first), scoped to the caller's merchant. */
  @Get()
  async list(@CurrentUser() user: AuthUser, @Query() query: OrderHistoryQuery) {
    const orders = await this.orders.findMany(user.merchantId, query);
    return orders.map(mapOrder);
  }

  /** Open bills (confirm-now-pay-later) for an outlet. Declared before :id so
   * Nest doesn't treat "open" as an order id. */
  @Get('open')
  async open(@CurrentUser() user: AuthUser, @Query() query: OpenOrdersQuery) {
    const orders = await this.orders.findOpen(user.merchantId, query.outletId);
    return orders.map(mapOrder);
  }

  @Get(':id')
  async getOne(@CurrentUser() user: AuthUser, @Param('id', ParseUUIDPipe) id: string) {
    const order = await this.orders.findById(user.merchantId, id);
    if (!order) throw new NotFoundException('Order not found');
    return mapOrder(order);
  }

  /** Edit an open bill (replace lines/discount/table) while it is AWAITING_PAYMENT. */
  @Post(':id/revise')
  async revise(
    @CurrentUser() user: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: OrderReviseDto,
  ) {
    const { order } = await this.orders.revise(user, id, dto);
    return mapOrder(order);
  }

  /** Settle an open bill: attach payment and complete it. Any cashier may settle. */
  @Post(':id/settle')
  async settle(
    @CurrentUser() user: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: SettleOrderDto,
    @Res({ passthrough: true }) res: Response,
  ) {
    const { order, replay } = await this.orders.settle(user, id, dto);
    res.status(replay ? 200 : 201);
    return mapOrder(order);
  }

  /**
   * Full-void a completed sale. OWNER only (Constitution VI) — a CASHIER is refused with 403.
   * Idempotent: a retry returns the same order with no second stock restoration.
   */
  @Post(':id/void')
  @HttpCode(200) // contract: 200 whether this is the first void or an idempotent retry
  // Any staff may initiate; a cashier must supply a manager PIN (enforced in the service).
  async void(
    @CurrentUser() user: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: VoidOrderDto,
  ) {
    const { order } = await this.voids.voidOrder(user, id, dto);
    return mapOrder(order); // effectiveStatus = VOIDED (derived, never stored)
  }

  /**
   * Refund a completed sale — full or line-level partial. OWNER/MANAGER only.
   * Idempotent via clientRefundId; multiple partial refunds allowed up to the total.
   */
  @Post(':id/refund')
  @HttpCode(200)
  // Any staff may initiate; a cashier must supply a manager PIN (enforced in the service).
  async refund(
    @CurrentUser() user: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: RefundOrderDto,
  ) {
    const { order } = await this.refunds.refundOrder(user, id, dto);
    return mapOrder(order);
  }
}
