import { Body, Controller, Get, HttpCode, Post, Query, UseGuards } from '@nestjs/common';
import { StaffRole } from '@prisma/client';
import { AuthGuard } from '../auth/auth.guard';
import { RolesGuard } from '../auth/roles.guard';
import { Roles } from '../auth/roles.decorator';
import { CurrentUser } from '../auth/current-user.decorator';
import { AuthUser } from '../auth/auth.types';
import { AttendanceService } from './attendance.service';
import { AttendanceQuery, ClockInDto } from './dto';

/** Self clock-in/out — any authenticated staff member. */
@Controller('attendance')
@UseGuards(AuthGuard, RolesGuard)
export class AttendanceController {
  constructor(private readonly attendance: AttendanceService) {}

  /** The caller's current open record (null when clocked out). */
  @Get('me')
  me(@CurrentUser() user: AuthUser) {
    return this.attendance.current(user);
  }

  @Post('clock-in')
  @HttpCode(200)
  clockIn(@CurrentUser() user: AuthUser, @Body() dto: ClockInDto) {
    return this.attendance.clockIn(user, dto.outletId);
  }

  @Post('clock-out')
  @HttpCode(200)
  clockOut(@CurrentUser() user: AuthUser) {
    return this.attendance.clockOut(user);
  }
}

/** Attendance report — owner/manager only. */
@Controller('admin/attendance')
@UseGuards(AuthGuard, RolesGuard)
@Roles(StaffRole.OWNER, StaffRole.MANAGER)
export class AdminAttendanceController {
  constructor(private readonly attendance: AttendanceService) {}

  @Get()
  list(@CurrentUser() user: AuthUser, @Query() query: AttendanceQuery) {
    return this.attendance.adminList(user.merchantId, query.from, query.to);
  }
}
