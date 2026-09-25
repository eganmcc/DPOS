import { Controller, Get, NotFoundException } from '@nestjs/common';
import { DemoService } from './demo.service';

/**
 * Public (no auth) — consumed by the app login screen for demo account switching.
 *
 * It hands out plaintext PINs, so it is off unless `DEMO_LOGINS=1` says this deployment is a demo
 * one. Unauthenticated and deliberately so: the login screen has no token yet. That is tolerable
 * for seeded demo tills and for nothing else, and an env flag is what keeps the two apart when the
 * same image ships to a real merchant.
 */
@Controller('demo')
export class DemoController {
  constructor(private readonly demo: DemoService) {}

  @Get('directory')
  directory() {
    if (process.env.DEMO_LOGINS !== '1') {
      // 404, not 403: on a production deployment this endpoint simply does not exist.
      throw new NotFoundException();
    }
    return this.demo.directory();
  }
}
