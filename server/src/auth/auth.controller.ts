import { Body, Controller, Post } from '@nestjs/common';
import { IsEmail, IsOptional, IsString, MinLength } from 'class-validator';
import { AuthService, AuthResult } from './auth.service';

class LoginDto {
  // Owner login
  @IsOptional()
  @IsEmail()
  email?: string;

  @IsOptional()
  @IsString()
  password?: string;

  // PIN login
  @IsOptional()
  @IsString()
  merchantId?: string;

  @IsOptional()
  @IsString()
  @MinLength(4)
  pin?: string;
}

@Controller('auth')
export class AuthController {
  constructor(private readonly auth: AuthService) {}

  @Post('login')
  async login(@Body() dto: LoginDto): Promise<AuthResult> {
    if (dto.email && dto.password) {
      return this.auth.loginOwner(dto.email, dto.password);
    }
    return this.auth.loginPin(dto.merchantId ?? '', dto.pin ?? '');
  }
}
