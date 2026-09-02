import { IsOptional, IsString, Matches } from 'class-validator';

export class ClockInDto {
  /** Outlet the staff clocked in at (the app's session outlet). Optional. */
  @IsOptional()
  @IsString()
  outletId?: string;
}

export class AttendanceQuery {
  /** Inclusive calendar day, `YYYY-MM-DD`. */
  @IsOptional()
  @Matches(/^\d{4}-\d{2}-\d{2}$/, { message: 'from must be YYYY-MM-DD' })
  from?: string;

  @IsOptional()
  @Matches(/^\d{4}-\d{2}-\d{2}$/, { message: 'to must be YYYY-MM-DD' })
  to?: string;
}
