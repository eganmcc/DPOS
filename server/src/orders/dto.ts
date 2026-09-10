import { Type } from 'class-transformer';
import {
  IsArray,
  IsBoolean,
  IsEnum,
  IsInt,
  IsNotEmpty,
  IsNumber,
  IsOptional,
  IsString,
  IsUUID,

  MaxLength,
  Matches,
  Max,
  Min,
  ValidateNested,
} from 'class-validator';
import { OrderType, PaymentMethod } from '@prisma/client';

export class DiscountDto {
  @IsEnum(['PERCENT', 'AMOUNT'])
  kind!: 'PERCENT' | 'AMOUNT';

  @IsInt()
  value!: number;

  @IsOptional()
  @IsString()
  reason?: string;

  @IsOptional()
  @IsString()
  approvedById?: string;
}

export class LineDto {
  @IsUUID()
  variantId!: string;

  @IsNumber()
  @Min(0)
  qty!: number;

  @IsOptional()
  @IsString()
  note?: string;

  @IsOptional()
  @IsArray()
  @IsUUID('all', { each: true })
  modifierIds?: string[];

  @IsOptional()
  @ValidateNested()
  @Type(() => DiscountDto)
  lineDiscount?: DiscountDto;
}

/** What the EDC terminal handed back for a card-present sale. Evidence only — never money math. */
export class EdcDto {
  @IsOptional()
  @IsString()
  scheme?: string; // VISA | MASTERCARD | BCA | JCB | OTHER

  @IsOptional()
  @IsString()
  @MaxLength(25)
  maskedPan?: string; // digits + asterisks only; the provider refuses an unmasked PAN

  @IsOptional()
  @IsString()
  entryMode?: string; // CHIP | CONTACTLESS | SWIPE

  @IsOptional()
  @IsString()
  @MaxLength(12)
  approvalCode?: string;

  @IsOptional()
  @IsString()
  @MaxLength(24)
  rrn?: string;

  @IsOptional()
  @IsString()
  @MaxLength(12)
  traceNo?: string;

  @IsOptional()
  @IsString()
  @MaxLength(12)
  batchNo?: string;

  @IsOptional()
  @IsString()
  @MaxLength(24)
  terminalId?: string;

  @IsOptional()
  @IsString()
  @MaxLength(64)
  cardholderName?: string;
}

/** The wallet's own reference for a settled e-wallet payment. */
export class WalletDto {
  @IsOptional()
  @IsString()
  @MaxLength(64)
  reference?: string;
}

export class PaymentDto {
  @IsEnum(PaymentMethod)
  method!: PaymentMethod;

  @IsOptional()
  @IsInt()
  tendered?: number;

  /** Card-present evidence, present for CARD_CREDIT / CARD_DEBIT / CARD_BCA. */
  @IsOptional()
  @ValidateNested()
  @Type(() => EdcDto)
  edc?: EdcDto;

  /** Wallet reference, present for the EWALLET_* tenders. */
  @IsOptional()
  @ValidateNested()
  @Type(() => WalletDto)
  wallet?: WalletDto;
}

export class OrderSubmitDto {
  @IsUUID()
  clientOrderId!: string;

  @IsUUID()
  outletId!: string;

  @IsOptional()
  @IsString()
  deviceId?: string;

  @IsOptional()
  @IsString()
  shiftId?: string;

  @IsEnum(OrderType)
  type!: OrderType;

  @IsOptional()
  @IsString()
  tableLabel?: string;

  @IsOptional()
  @ValidateNested()
  @Type(() => DiscountDto)
  orderDiscount?: DiscountDto;

  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => LineDto)
  lines!: LineDto[];

  /**
   * Present → settle immediately (order stored COMPLETED). Absent → confirm as an
   * open bill (AWAITING_PAYMENT); stock is still reserved and the bill is settled
   * later via POST /orders/:id/settle.
   */
  @IsOptional()
  @ValidateNested()
  @Type(() => PaymentDto)
  payment?: PaymentDto;
}

export class SettleOrderDto {
  /** Device idempotency key (retries are safe; the status flip is authoritative). */
  @IsUUID()
  clientSettleId!: string;

  @ValidateNested()
  @Type(() => PaymentDto)
  payment!: PaymentDto;
}

/** Edit an open bill: replace its lines/discount/type/table while it is AWAITING_PAYMENT. */
export class OrderReviseDto {
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => LineDto)
  lines!: LineDto[];

  @IsOptional()
  @IsEnum(OrderType)
  type?: OrderType;

  @IsOptional()
  @ValidateNested()
  @Type(() => DiscountDto)
  orderDiscount?: DiscountDto;

  @IsOptional()
  @IsString()
  tableLabel?: string;
}

export class OpenOrdersQuery {
  @IsUUID()
  outletId!: string;
}

export class VoidOrderDto {
  /** Device idempotency key — a retry with the same value is a no-op (Constitution V). */
  @IsOptional()
  @IsUUID()
  clientVoidId?: string;

  /** Required: why the sale is being voided (audit trail). */
  @IsString()
  @IsNotEmpty({ message: 'A void reason is required' })
  reason!: string;

  /** Manager/owner PIN authorizing a cashier-initiated void (ignored for owner/manager). */
  @IsOptional()
  @IsString()
  approverPin?: string;
}

export class RefundLineDto {
  @IsUUID()
  orderLineId!: string;

  /** Quantity of this line to refund (supports fractional/weighed goods). */
  @IsNumber()
  @Min(0)
  qty!: number;
}

export class RefundOrderDto {
  /** Device idempotency key — a retry with the same value returns the same refund. */
  @IsOptional()
  @IsUUID()
  clientRefundId?: string;

  /** Required: why the sale is being refunded (audit trail). */
  @IsString()
  @IsNotEmpty({ message: 'A refund reason is required' })
  reason!: string;

  /** Refund the whole remaining amount (ignores `lines`). */
  @IsOptional()
  @IsBoolean()
  full?: boolean;

  /** Line-level partial refund. Required unless `full` is true. */
  @IsOptional()
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => RefundLineDto)
  lines?: RefundLineDto[];

  /** Manager/owner PIN authorizing a cashier-initiated refund (ignored for owner/manager). */
  @IsOptional()
  @IsString()
  approverPin?: string;
}

export class CancelOrderDto {
  /** Required: why the unpaid open bill is being cancelled (audit trail). */
  @IsString()
  @IsNotEmpty({ message: 'A cancel reason is required' })
  reason!: string;

  /** Manager/owner PIN authorizing a cashier-initiated cancel (ignored for owner/manager). */
  @IsOptional()
  @IsString()
  approverPin?: string;
}

export class OrderHistoryQuery {
  @IsUUID()
  outletId!: string;

  /** Inclusive calendar day, `YYYY-MM-DD`. */
  @IsOptional()
  @Matches(/^\d{4}-\d{2}-\d{2}$/, { message: 'from must be YYYY-MM-DD' })
  from?: string;

  /** Inclusive calendar day, `YYYY-MM-DD`. */
  @IsOptional()
  @Matches(/^\d{4}-\d{2}-\d{2}$/, { message: 'to must be YYYY-MM-DD' })
  to?: string;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(200)
  limit?: number;
}
