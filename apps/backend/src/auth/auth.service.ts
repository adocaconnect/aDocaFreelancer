import { Injectable, UnauthorizedException, BadRequestException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import * as bcrypt from 'bcryptjs';
import { JwtService } from '@nestjs/jwt';
import { RefreshTokenService } from './refresh-token.service';

@Injectable()
export class AuthService {
  private accessTokenTtl = process.env.JWT_ACCESS_TTL || '15m'; // allow override
  private refreshTokenDays = Number(process.env.REFRESH_TOKEN_DAYS || 30);

  constructor(
    private prisma: PrismaService,
    private jwt: JwtService,
    private refreshTokenService: RefreshTokenService,
  ) {}

  async register(data: { name: string; email: string; password: string; role: string }) {
    const existing = await this.prisma.user.findUnique({ where: { email: data.email } });
    if (existing) throw new BadRequestException('Email already in use');
    const hash = await bcrypt.hash(data.password, 10);
    const user = await this.prisma.user.create({
      data: {
        name: data.name,
        email: data.email,
        passwordHash: hash,
        role: data.role as any,
        profile: { create: { bio: '', skills: [] } },
      },
    });
    const tokens = await this.generateTokens(user.id, user.email, user.role);
    return { user: { id: user.id, email: user.email, name: user.name, role: user.role }, ...tokens };
  }

  async validateUser(email: string, password: string) {
    const user = await this.prisma.user.findUnique({ where: { email } });
    if (!user) return null;
    const ok = await bcrypt.compare(password, user.passwordHash);
    if (!ok) return null;
    return user;
  }

  async login(email: string, password: string) {
    const user = await this.validateUser(email, password);
    if (!user) throw new UnauthorizedException('Invalid credentials');
    const tokens = await this.generateTokens(user.id, user.email, user.role);
    return { user: { id: user.id, email: user.email, name: user.name, role: user.role }, ...tokens };
  }

  private signAccessToken(userId: string, email: string, role: string) {
    const payload = { sub: userId, email, role };
    return this.jwt.sign(payload, {
      secret: process.env.JWT_ACCESS_TOKEN_SECRET || 'change_me',
      expiresIn: this.accessTokenTtl,
    });
  }

  async generateTokens(userId: string, email: string, role: string) {
    const accessToken = this.signAccessToken(userId, email, role);
    const refreshToken = await this.refreshTokenService.create(userId, this.refreshTokenDays);
    return { accessToken, refreshToken, expiresIn: this.accessTokenTtl };
  }

  async refresh(refreshPacked: string) {
    const valid = await this.refreshTokenService.validateAndConsume(refreshPacked);
    if (!valid) throw new UnauthorizedException('Invalid refresh token');

    // rotate: create new refresh token and revoke old
    const newRefresh = await this.refreshTokenService.rotate(valid.id, valid.userId, this.refreshTokenDays);

    const user = await this.prisma.user.findUnique({ where: { id: valid.userId } });
    if (!user) throw new UnauthorizedException('User not found');

    const accessToken = this.signAccessToken(user.id, user.email, user.role);
    return { accessToken, refreshToken: newRefresh, expiresIn: this.accessTokenTtl };
  }

  async logout(refreshPacked: string) {
    const valid = await this.refreshTokenService.validateAndConsume(refreshPacked);
    if (!valid) return false;
    await this.refreshTokenService.revoke(valid.id, valid.userId);
    return true;
  }
}