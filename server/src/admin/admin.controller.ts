import { Body, Controller, Get, Param, ParseUUIDPipe, Patch, Post, Query, UseGuards } from '@nestjs/common';
import { StaffRole } from '@prisma/client';
import { AuthGuard } from '../auth/auth.guard';
import { RolesGuard } from '../auth/roles.guard';
import { Roles } from '../auth/roles.decorator';
import { CurrentUser } from '../auth/current-user.decorator';
import { AuthUser } from '../auth/auth.types';
import { EntityService } from './entity.service';
import { StaffService } from './staff.service';
import { ProductsService } from './products.service';
import { InventoryService } from './inventory.service';
import { DashboardService } from './dashboard.service';
import {
  AdjustStockDto,
  CreateBranchDto,
  CreateStaffDto,
  DashboardQuery,
  OutletQuery,
  SetPinDto,
  UpdateBranchDto,
  UpdateMerchantDto,
  UpdateStaffDto,
  UpdateVariantDto,
  CreateProductDto,
} from './dto';

// Every admin surface is OWNER-only and merchant-scoped from the token.
@Controller('admin/entity')
@UseGuards(AuthGuard, RolesGuard)
@Roles(StaffRole.OWNER)
export class EntityController {
  constructor(private readonly entity: EntityService) {}

  @Get()
  get(@CurrentUser() u: AuthUser) {
    return this.entity.getMerchant(u.merchantId);
  }

  @Patch()
  update(@CurrentUser() u: AuthUser, @Body() dto: UpdateMerchantDto) {
    return this.entity.updateMerchant(u.merchantId, dto);
  }

  @Get('branches')
  branches(@CurrentUser() u: AuthUser) {
    return this.entity.listBranches(u.merchantId);
  }

  @Post('branches')
  createBranch(@CurrentUser() u: AuthUser, @Body() dto: CreateBranchDto) {
    return this.entity.createBranch(u.merchantId, dto);
  }

  @Patch('branches/:id')
  updateBranch(
    @CurrentUser() u: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: UpdateBranchDto,
  ) {
    return this.entity.updateBranch(u.merchantId, id, dto);
  }
}

@Controller('admin/staff')
@UseGuards(AuthGuard, RolesGuard)
@Roles(StaffRole.OWNER)
export class StaffController {
  constructor(private readonly staff: StaffService) {}

  @Get()
  list(@CurrentUser() u: AuthUser) {
    return this.staff.list(u.merchantId);
  }

  @Post()
  create(@CurrentUser() u: AuthUser, @Body() dto: CreateStaffDto) {
    return this.staff.create(u.merchantId, dto);
  }

  @Patch(':id')
  update(@CurrentUser() u: AuthUser, @Param('id', ParseUUIDPipe) id: string, @Body() dto: UpdateStaffDto) {
    return this.staff.update(u.merchantId, id, dto);
  }

  @Post(':id/pin')
  setPin(@CurrentUser() u: AuthUser, @Param('id', ParseUUIDPipe) id: string, @Body() dto: SetPinDto) {
    return this.staff.setPin(u.merchantId, id, dto);
  }
}

@Controller('admin/products')
@UseGuards(AuthGuard, RolesGuard)
@Roles(StaffRole.OWNER)
export class ProductsController {
  constructor(private readonly products: ProductsService) {}

  @Get()
  list(@CurrentUser() u: AuthUser) {
    return this.products.list(u.merchantId);
  }

  @Post()
  create(@CurrentUser() u: AuthUser, @Body() dto: CreateProductDto) {
    return this.products.createProduct(u, dto);
  }

  @Patch('variants/:id')
  updateVariant(
    @CurrentUser() u: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: UpdateVariantDto,
  ) {
    return this.products.updateVariant(u.merchantId, id, dto);
  }
}

@Controller('admin/inventory')
@UseGuards(AuthGuard, RolesGuard)
@Roles(StaffRole.OWNER)
export class InventoryController {
  constructor(private readonly inventory: InventoryService) {}

  @Get()
  list(@CurrentUser() u: AuthUser, @Query() q: OutletQuery) {
    return this.inventory.list(u.merchantId, q.outletId!);
  }

  @Post('adjust')
  adjust(@CurrentUser() u: AuthUser, @Body() dto: AdjustStockDto) {
    return this.inventory.adjust(u, dto);
  }
}

@Controller('admin/dashboard')
@UseGuards(AuthGuard, RolesGuard)
@Roles(StaffRole.OWNER, StaffRole.MANAGER)
export class DashboardController {
  constructor(private readonly dashboard: DashboardService) {}

  @Get()
  summary(@CurrentUser() u: AuthUser, @Query() q: DashboardQuery) {
    return this.dashboard.summary(u.merchantId, q);
  }
}
