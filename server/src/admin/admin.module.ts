import { Module } from '@nestjs/common';
import {
  DashboardController,
  EntityController,
  InventoryController,
  ProductsController,
  StaffController,
  BankController,
  JournalController,
} from './admin.controller';
import { EntityService } from './entity.service';
import { StaffService } from './staff.service';
import { ProductsService } from './products.service';
import { InventoryService } from './inventory.service';
import { DashboardService } from './dashboard.service';
import { BankService } from './bank.service';
import { JournalService } from './journal.service';

/** Admin (customer portal) API — OWNER-gated CRUD + sales dashboard. */
@Module({
  controllers: [
    EntityController,
    StaffController,
    ProductsController,
    InventoryController,
    DashboardController,
    BankController,
    JournalController,
  ],
  providers: [EntityService, StaffService, ProductsService, InventoryService, DashboardService, BankService, JournalService],
})
export class AdminModule {}
