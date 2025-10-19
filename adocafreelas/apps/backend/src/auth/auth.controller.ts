import { Body, Controller, Post } from '@nestjs/common';
import { AuthService } from './auth.service';
import { RegisterDto } from './dto/register.dto';
import { LoginDto } from './dto/login.dto';
import { RefreshDto } from './dto/refresh.dto';

@Controller('auth')
export class AuthController {
  constructor(private service: AuthService) {}

  @Post('register')
  async register(@Body() body: RegisterDto) {
    return this.service.register(body);
  }

  @Post('login')
  async login(@Body() body: LoginDto) {
    return this.service.login(body.email, body.password);
  }

  @Post('refresh')
  async refresh(@Body() body: RefreshDto) {
    return this.service.refresh(body.refreshToken);
  }

  @Post('logout')
  async logout(@Body() body: RefreshDto) {
    const ok = await this.service.logout(body.refreshToken);
    return { ok };
  }

  @Post('verify-email')
  async verifyEmail(@Body() body: { token: string }) {
    // stub for email verification flow
    return { ok: true };
  }
}