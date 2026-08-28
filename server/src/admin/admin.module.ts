import { Module } from '@nestjs/common';
import {
  DashboardController,
  EntityController,
  InventoryController,
  ProductsController,
  StaffController,
} from './admin.controller';
import { EntityService } from './entity.service';
import { StaffService } from './staff.service';
import { ProductsService } from './products.service';
import { InventoryService } from './inventory.service';
import { DashboardService } from './dashboard.service';

/** Admin (customer portal) API — OWNER-gated CRUD + sales dashboard. */
@Module({
  controllers: [
    EntityController,
    StaffController,
    ProductsController,
    InventoryController,
    DashboardController,
  ],
  providers: [EntityService, StaffService, ProductsService, InventoryService, DashboardService],
})
export class AdminModule {}
