import { Controller, Get, Query, UseGuards } from '@nestjs/common';
import { IsString } from 'class-validator';
import { AuthGuard } from '../auth/auth.guard';
import { CurrentUser } from '../auth/current-user.decorator';
import { AuthUser } from '../auth/auth.types';
import { CatalogService } from './catalog.service';

class CatalogQuery {
  @IsString()
  outletId!: string;
}

@Controller('catalog')
@UseGuards(AuthGuard)
export class CatalogController {
  constructor(private readonly catalog: CatalogService) {}

  @Get()
  async get(@CurrentUser() user: AuthUser, @Query() query: CatalogQuery) {
    return this.catalog.getCatalog(user.merchantId, query.outletId);
  }
}
