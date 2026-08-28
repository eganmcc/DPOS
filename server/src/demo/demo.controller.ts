import { Controller, Get } from '@nestjs/common';
import { DemoService } from './demo.service';

/** Public (no auth) — consumed by the app login screen for demo account switching. */
@Controller('demo')
export class DemoController {
  constructor(private readonly demo: DemoService) {}

  @Get('directory')
  directory() {
    return this.demo.directory();
  }
}
