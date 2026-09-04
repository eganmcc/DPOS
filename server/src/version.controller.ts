import { Controller, Get } from '@nestjs/common';
import * as fs from 'fs';
import * as path from 'path';

/** Read the server version from package.json at runtime (never hardcoded). */
function readVersion(): string {
  const candidates = [
    path.join(process.cwd(), 'package.json'),
    path.join(__dirname, '..', 'package.json'),
    path.join(__dirname, '..', '..', 'package.json'),
  ];
  for (const p of candidates) {
    try {
      return JSON.parse(fs.readFileSync(p, 'utf8')).version as string;
    } catch {
      /* try next candidate */
    }
  }
  return 'unknown';
}

const VERSION = readVersion();

/** Public build-info endpoint (no auth) used by the app's Settings screen. */
@Controller('version')
export class VersionController {
  @Get()
  get() {
    return { name: 'dpos-server', version: VERSION };
  }
}
