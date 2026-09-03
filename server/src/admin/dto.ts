import {
  IsBoolean,
  IsEnum,
  IsInt,
  IsOptional,
  IsString,
  IsUUID,
  Matches,
  Min,
  MinLength,
} from 'class-validator';
import { BusinessType, OutletPaymentMode, StaffRole } from '@prisma/client';

// ---------- Entity / company ----------
export class UpdateMerchantDto {
  @IsOptional() @IsString() name?: string;
  @IsOptional() @IsEnum(BusinessType) businessType?: BusinessType;
  @IsOptional() @IsString() logoUrl?: string;
}

// ---------- Branches (outlets) ----------
export class CreateBranchDto {
  @IsOptional() @IsString() code?: string;
  @IsString() name!: string;
  @IsOptional() @IsString() address?: string;
  @IsOptional() @IsUUID() managerId?: string;
  @IsOptional() @IsEnum(OutletPaymentMode) paymentMode?: OutletPaymentMode;
}

export class UpdateBranchDto {
  @IsOptional() @IsString() code?: string;
  @IsOptional() @IsString() name?: string;
  @IsOptional() @IsString() address?: string;
  @IsOptional() @IsUUID() managerId?: string;
  @IsOptional() @IsEnum(OutletPaymentMode) paymentMode?: OutletPaymentMode;
  @IsOptional() @IsBoolean() isActive?: boolean;
}

// ---------- Staff / resources ----------
export class CreateStaffDto {
  @IsString() name!: string;
  @IsOptional() @IsString() phone?: string;
  @IsEnum(StaffRole) role!: StaffRole;
  @IsOptional() @IsUUID() outletId?: string; // null/absent = HQ / all branches
  @IsString() @Matches(/^\d{4,6}$/, { message: 'pin must be 4-6 digits' }) pin!: string;
  @IsOptional() @IsString() email?: string;
  @IsOptional() @IsString() @MinLength(6) password?: string;
}

export class UpdateStaffDto {
  @IsOptional() @IsString() name?: string;
  @IsOptional() @IsString() phone?: string;
  @IsOptional() @IsEnum(StaffRole) role?: StaffRole;
  @IsOptional() @IsUUID() outletId?: string;
  @IsOptional() @IsString() email?: string;
  @IsOptional() @IsBoolean() isActive?: boolean;
}

export class SetPinDto {
  @IsString() @Matches(/^\d{4,6}$/, { message: 'pin must be 4-6 digits' }) pin!: string;
}

// ---------- Prices ----------
export class UpdateVariantDto {
  @IsOptional() @IsInt() @Min(0) price?: number;
  @IsOptional() @IsInt() @Min(0) costPrice?: number;
  @IsOptional() @IsBoolean() isAvailable?: boolean;
  /** SKU / barcode. Empty string clears it (stored as null). */
  @IsOptional() @IsString() sku?: string;
}

/** Create a new product with a single default variant (portal Prices → Add item). */
export class CreateProductDto {
  @IsString() @MinLength(1) name!: string;
  /** Category by name — found or created for this merchant. */
  @IsString() @MinLength(1) categoryName!: string;
  /** Variant/unit label (e.g. "Pcs", "Regular"). Defaults server-side when omitted. */
  @IsOptional() @IsString() variantName?: string;
  @IsInt() @Min(0) price!: number;
  @IsOptional() @IsInt() @Min(0) costPrice?: number;
  @IsOptional() @IsString() sku?: string;
  @IsOptional() @IsBoolean() trackInventory?: boolean;
  /** Opening stock to receive at [outletId] (requires outletId, trackInventory). */
  @IsOptional() @IsInt() @Min(0) initialStock?: number;
  @IsOptional() @IsUUID() outletId?: string;
}

// ---------- Inventory ----------
export class AdjustStockDto {
  @IsUUID() outletId!: string;
  @IsUUID() variantId!: string;
  /** New on-hand quantity to set; the delta is written as an ADJUSTMENT movement. */
  @IsInt() @Min(0) quantityOnHand!: number;
}

// ---------- Query ----------
export class OutletQuery {
  @IsOptional() @IsUUID() outletId?: string;
}

export class DashboardQuery {
  @IsOptional() @IsUUID() outletId?: string;
  @IsOptional() @Matches(/^\d{4}-\d{2}-\d{2}$/) from?: string;
  @IsOptional() @Matches(/^\d{4}-\d{2}-\d{2}$/) to?: string;
}
