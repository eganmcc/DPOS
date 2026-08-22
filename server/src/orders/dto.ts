import { Type } from 'class-transformer';
import {
  IsArray,
  IsEnum,
  IsInt,
  IsNumber,
  IsOptional,
  IsString,
  IsUUID,
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

export class PaymentDto {
  @IsEnum(PaymentMethod)
  method!: PaymentMethod;

  @IsOptional()
  @IsInt()
  tendered?: number;
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

  @ValidateNested()
  @Type(() => PaymentDto)
  payment!: PaymentDto;
}
