import {
  Body,
  Controller,
  Get,
  Headers,
  Param,
  ParseUUIDPipe,
  Patch,
  Post,
  Query,
  UseGuards,
} from '@nestjs/common';
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
import { BankService } from './bank.service';
import { JournalService } from './journal.service';
import {
  AdjustStockDto,
  CreateBranchDto,
  CreateStaffDto,
  DashboardQuery,
  JournalQuery,
  OutletQuery,
  SetPinDto,
  UpdateBranchDto,
  UpdateMerchantDto,
  UpdateStaffDto,
  UpdateVariantDto,
  CreateProductDto,
  IngestSettlementDto,
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

/**
 * Reporting for the acquiring bank (specs/011-bank-reporting).
 *
 * OWNER-only like every other admin surface, and merchant-scoped from the token — a bank reads a
 * merchant's figures with that merchant's own credentials and consent, never across the tenancy.
 */
@Controller('admin/bank')
@UseGuards(AuthGuard, RolesGuard)
@Roles(StaffRole.OWNER)
export class BankController {
  constructor(private readonly bank: BankService) {}

  /** The acquirer's settlement lines, stored as sent. */
  @Post('settlement')
  ingest(@CurrentUser() user: AuthUser, @Body() dto: IngestSettlementDto) {
    return this.bank.ingestSettlement(user.merchantId, dto.rows);
  }

  /** Ours against theirs. The match rate is what makes the cash figure believable. */
  @Get('reconciliation')
  reconciliation(@CurrentUser() user: AuthUser, @Query() q: DashboardQuery) {
    return this.bank.reconciliation(user.merchantId, q);
  }

  /**
   * Of the merchants handed this app, how many ever rang a sale — and who has gone quiet.
   *
   * Cross-merchant by nature, which the OWNER token is not: it belongs to ONE merchant. The
   * portfolio view is therefore unlocked by a separate bank key (`BANK_PORTFOLIO_KEY`), and
   * without it this returns the caller's own merchant and nobody else's.
   */
  @Get('activation')
  activation(
    @CurrentUser() user: AuthUser,
    @Headers('x-bank-key') bankKey?: string,
    @Query('bankBranch') bankBranch?: string,
  ) {
    const expected = process.env.BANK_PORTFOLIO_KEY;
    const portfolio = !!expected && bankKey === expected;
    return this.bank.activation(user.merchantId, { portfolio, bankBranch });
  }

  /** The monthly figures a scorecard eats. Refused without the merchant's consent. */
  @Get('credit-profile')
  creditProfile(@CurrentUser() user: AuthUser, @Query('months') months?: string) {
    return this.bank.creditProfile(user.merchantId, Math.min(24, Number(months) || 12));
  }

  /** Laporan Laba Rugi Sederhana. */
  @Get('profit-loss')
  profitAndLoss(@CurrentUser() user: AuthUser, @Query() q: DashboardQuery & { expenses?: string }) {
    return this.bank.profitAndLoss(user.merchantId, {
      ...q,
      expenses: q.expenses ? Number(q.expenses) : 0,
    });
  }

  /** What could distort the numbers, said out loud. */
  @Get('integrity')
  integrity(@CurrentUser() user: AuthUser, @Query() q: DashboardQuery) {
    return this.bank.integrity(user.merchantId, q);
  }
}

/**
 * Transaction-level and journal reporting (specs/011-bank-reporting).
 *
 * Merchant-scoped from the token like every other admin surface. Managers can read these — they
 * are the day's own figures, and a manager closing a till needs the daily recap.
 */
@Controller('admin/journal')
@UseGuards(AuthGuard, RolesGuard)
@Roles(StaffRole.OWNER, StaffRole.MANAGER)
export class JournalController {
  constructor(private readonly journal: JournalService) {}

  /** Every transaction, corrections included and labelled. */
  @Get('transactions')
  transactions(
    @CurrentUser() user: AuthUser,
    @Query() q: JournalQuery,
  ) {
    return this.journal.transactions(user.merchantId, q);
  }

  /** One row per day — the end-of-day recap. */
  @Get('daily')
  daily(@CurrentUser() user: AuthUser, @Query() q: DashboardQuery) {
    return this.journal.daily(user.merchantId, q);
  }

  /** Voids, refunds and abandoned bills, with reasons and approvers. */
  @Get('corrections')
  corrections(@CurrentUser() user: AuthUser, @Query() q: DashboardQuery) {
    return this.journal.corrections(user.merchantId, q);
  }

  /** Tax and service charge collected. */
  @Get('tax')
  tax(@CurrentUser() user: AuthUser, @Query() q: DashboardQuery) {
    return this.journal.tax(user.merchantId, q);
  }

  /** Double-entry postings an accountant can post. */
  @Get('general')
  general(@CurrentUser() user: AuthUser, @Query() q: DashboardQuery) {
    return this.journal.generalJournal(user.merchantId, q);
  }
}
