import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import * as bcrypt from 'bcryptjs';
import { randomBytes } from 'crypto';
import { v4 as uuidv4 } from 'uuid';

@Injectable()
export class RefreshTokenService {
  constructor(private prisma: PrismaService) {}

  private async hashToken(token: string) {
    return bcrypt.hash(token, 10);
  }

  private generatePlainToken() {
    return randomBytes(48).toString('hex'); // 96 chars hex
  }

  async create(userId: string, expiresInDays = 30) {
    const id = uuidv4();
    const plainToken = this.generatePlainToken();
    const tokenHash = await this.hashToken(plainToken);
    const expiresAt = new Date(Date.now() + expiresInDays * 24 * 60 * 60 * 1000);
    const record = await this.prisma.refreshToken.create({
      data: { id, tokenHash, userId, expiresAt },
    });
    // We return a string that the client stores: "<id>::<plainToken>"
    return `${record.id}::${plainToken}`;
  }

  async rotate(oldTokenId: string, userId: string, expiresInDays = 30) {
    // Revoke old token and create new one
    await this.prisma.refreshToken.updateMany({
      where: { id: oldTokenId, userId },
      data: { revoked: true },
    });
    return this.create(userId, expiresInDays);
  }

  async revoke(tokenId: string, userId?: string) {
    const where: any = { id: tokenId };
    if (userId) where.userId = userId;
    const res = await this.prisma.refreshToken.updateMany({
      where,
      data: { revoked: true },
    });
    return res.count > 0;
  }

  async validateAndConsume(packed: string) {
    // packed = "<id>::<plainToken>"
    if (!packed || !packed.includes('::')) return null;
    const [id, plain] = packed.split('::');
    if (!id || !plain) return null;
    const tokenRecord = await this.prisma.refreshToken.findUnique({ where: { id } });
    if (!tokenRecord) return null;
    if (tokenRecord.revoked) return null;
    if (tokenRecord.expiresAt < new Date()) return null;
    const ok = await bcrypt.compare(plain, tokenRecord.tokenHash);
    if (!ok) return null;
    // return payload
    return { id: tokenRecord.id, userId: tokenRecord.userId };
  }
}