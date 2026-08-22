import { Body, Controller, Get, NotFoundException, Param, Post, Res, UseGuards } from '@nestjs/common';
import { Response } from 'express';
import { AuthGuard } from '../auth/auth.guard';
import { CurrentUser } from '../auth/current-user.decorator';
import { AuthUser } from '../auth/auth.types';
import { OrdersService } from './orders.service';
import { OrderSubmitDto } from './dto';
import { mapOrder } from './order.mapper';

@Controller('orders')
@UseGuards(AuthGuard)
export class OrdersController {
  constructor(private readonly orders: OrdersService) {}

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

  @Get(':id')
  async getOne(@CurrentUser() user: AuthUser, @Param('id') id: string) {
    const order = await this.orders.findById(user.merchantId, id);
    if (!order) throw new NotFoundException('Order not found');
    return mapOrder(order);
  }
}
