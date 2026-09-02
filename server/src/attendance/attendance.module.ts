import { Module } from '@nestjs/common';
import { AttendanceService } from './attendance.service';
import { AttendanceController, AdminAttendanceController } from './attendance.controller';

@Module({
  providers: [AttendanceService],
  controllers: [AttendanceController, AdminAttendanceController],
  exports: [AttendanceService],
})
export class AttendanceModule {}
