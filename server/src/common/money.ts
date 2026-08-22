/**
 * Server-authoritative money engine (Constitution III).
 * All amounts are integer rupiah. Discounts are PERCENT (basis points) or AMOUNT (rupiah).
 * Rates (tax/service) are basis points: 1000 = 10%.
 *
 * This is a pure function — no DB, no framework — so it is trivially unit-testable and is the
 * single source of truth for what a customer is charged. Client-sent totals are never used.
 */

export type DiscountKind = 'PERCENT' | 'AMOUNT';

export interface DiscountInput {
  kind: DiscountKind;
  value: number; // PERCENT: basis points; AMOUNT: rupiah
  reason?: string | null;
  approvedById?: string | null;
}

export interface VariantInfo {
  id: string;
  productName: string;
  sku?: string | null;
  price: number; // rupiah
  costPrice?: number | null;
  trackInventory: boolean;
}

export interface ModifierInfo {
  id: string;
  name: string;
  priceDelta: number; // rupiah
}

export interface LineInput {
  variantId: string;
  qty: number;
  note?: string | null;
  modifierIds?: string[];
  lineDiscount?: DiscountInput | null;
}

export interface OrderComputeInput {
  lines: LineInput[];
  orderDiscount?: DiscountInput | null;
}

export interface TaxRuleInfo {
  label: string;
  rateBps: number;
  serviceChargeBps?: number | null;
  serviceLabel?: string | null;
}

export interface ComputedLine {
  variantId: string;
  qty: number;
  productNameSnapshot: string;
  skuSnapshot?: string | null;
  unitPriceSnapshot: number; // base variant price + modifier deltas, per unit
  costPriceSnapshot?: number | null;
  selectedModifiersSnapshot: { id: string; name: string; priceDelta: number }[];
  lineDiscount: number; // calculated
  lineTotal: number; // gross - lineDiscount
  lineGross: number; // unitPrice * qty (before line discount)
  trackInventory: boolean;
}

export interface ComputedDiscount {
  scope: 'ORDER' | 'LINE';
  kind: DiscountKind;
  value: number;
  discountAmount: number;
  reason?: string | null;
  approvedById?: string | null;
  lineIndex?: number; // for LINE scope
}

export interface ComputedOrder {
  lines: ComputedLine[];
  discounts: ComputedDiscount[];
  subtotal: number;
  discountTotal: number;
  taxTotal: number;
  serviceChargeTotal: number;
  grandTotal: number;
  taxLabelSnapshot: string;
  taxRateBpsSnapshot: number;
  serviceChargeLabelSnapshot?: string | null;
  serviceChargeRateBpsSnapshot?: number | null;
}

function discountAmountFor(base: number, d: DiscountInput): number {
  if (d.kind === 'PERCENT') {
    return Math.round((base * d.value) / 10000);
  }
  // AMOUNT — never discount more than the base
  return Math.min(Math.max(0, d.value), base);
}

export function computeOrder(
  input: OrderComputeInput,
  variants: Map<string, VariantInfo>,
  modifiers: Map<string, ModifierInfo>,
  taxRule: TaxRuleInfo,
): ComputedOrder {
  const lines: ComputedLine[] = [];
  const discounts: ComputedDiscount[] = [];

  input.lines.forEach((li, idx) => {
    const v = variants.get(li.variantId);
    if (!v) {
      throw new Error(`Unknown variantId: ${li.variantId}`);
    }
    const selectedModifiers = (li.modifierIds ?? []).map((id) => {
      const m = modifiers.get(id);
      if (!m) throw new Error(`Unknown modifierId: ${id}`);
      return { id: m.id, name: m.name, priceDelta: m.priceDelta };
    });
    const modifierDelta = selectedModifiers.reduce((s, m) => s + m.priceDelta, 0);
    const unitPrice = v.price + modifierDelta;
    const lineGross = Math.round(unitPrice * li.qty);

    let lineDiscount = 0;
    if (li.lineDiscount) {
      lineDiscount = discountAmountFor(lineGross, li.lineDiscount);
      discounts.push({
        scope: 'LINE',
        kind: li.lineDiscount.kind,
        value: li.lineDiscount.value,
        discountAmount: lineDiscount,
        reason: li.lineDiscount.reason ?? null,
        approvedById: li.lineDiscount.approvedById ?? null,
        lineIndex: idx,
      });
    }

    lines.push({
      variantId: v.id,
      qty: li.qty,
      productNameSnapshot: v.productName,
      skuSnapshot: v.sku ?? null,
      unitPriceSnapshot: unitPrice,
      costPriceSnapshot: v.costPrice ?? null,
      selectedModifiersSnapshot: selectedModifiers,
      lineDiscount,
      lineTotal: lineGross - lineDiscount,
      lineGross,
      trackInventory: v.trackInventory,
    });
  });

  const subtotal = lines.reduce((s, l) => s + l.lineGross, 0);
  const lineDiscountSum = lines.reduce((s, l) => s + l.lineDiscount, 0);
  const baseAfterLineDiscounts = subtotal - lineDiscountSum;

  let orderDiscountAmount = 0;
  if (input.orderDiscount) {
    orderDiscountAmount = discountAmountFor(baseAfterLineDiscounts, input.orderDiscount);
    discounts.push({
      scope: 'ORDER',
      kind: input.orderDiscount.kind,
      value: input.orderDiscount.value,
      discountAmount: orderDiscountAmount,
      reason: input.orderDiscount.reason ?? null,
      approvedById: input.orderDiscount.approvedById ?? null,
    });
  }

  const discountTotal = lineDiscountSum + orderDiscountAmount;
  const taxableBase = subtotal - discountTotal;
  const taxTotal = Math.round((taxableBase * taxRule.rateBps) / 10000);
  const serviceChargeTotal = taxRule.serviceChargeBps
    ? Math.round((taxableBase * taxRule.serviceChargeBps) / 10000)
    : 0;
  const grandTotal = taxableBase + taxTotal + serviceChargeTotal;

  return {
    lines,
    discounts,
    subtotal,
    discountTotal,
    taxTotal,
    serviceChargeTotal,
    grandTotal,
    taxLabelSnapshot: taxRule.label,
    taxRateBpsSnapshot: taxRule.rateBps,
    serviceChargeLabelSnapshot: taxRule.serviceLabel ?? null,
    serviceChargeRateBpsSnapshot: taxRule.serviceChargeBps ?? null,
  };
}
