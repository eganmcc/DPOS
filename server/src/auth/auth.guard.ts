import { CanActivate, ExecutionContext, Injectable, UnauthorizedException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { Request } from 'express';
import { JwtPayload } from './auth.types';

@Injectable()
export class AuthGuard implements CanActivate {
  constructor(private readonly jwt: JwtService) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const req = context.switchToHttp().getRequest<Request>();
    const header = req.headers.authorization;
    if (!header || !header.startsWith('Bearer ')) {
      throw new UnauthorizedException('Missing bearer token');
    }
    const token = header.slice('Bearer '.length);
    try {
      const payload = await this.jwt.verifyAsync<JwtPayload>(token);
      // Attach the authenticated tenant context. Every service scopes by merchantId.
      (req as Request & { user?: unknown }).user = {
        staffId: payload.sub,
        merchantId: payload.merchantId,
        role: payload.role,
      };
      return true;
    } catch {
      throw new UnauthorizedException('Invalid token');
    }
  }
}
