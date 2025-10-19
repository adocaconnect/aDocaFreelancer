import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';
import { setupSwagger } from './swagger';
import * as helmet from 'helmet';
import * as cookieParser from 'cookie-parser';
import { ValidationPipe, Logger } from '@nestjs/common';

async function bootstrap() {
  const logger = new Logger('Bootstrap');
  const app = await NestFactory.create(AppModule);

  // Security middlewares
  app.use(helmet());
  app.enableCors({
    origin: process.env.FRONTEND_URL || 'http://localhost:3000',
    credentials: true,
  });
  app.use(cookieParser());

  // Global Validation
  app.useGlobalPipes(new ValidationPipe({ whitelist: true, forbidNonWhitelisted: false, transform: true }));

  setupSwagger(app);
  await checkEnv(logger);

  const port = process.env.PORT ? +process.env.PORT : 4000;
  await app.listen(port);
  logger.log(`Backend running on ${await app.getUrl()}`);
}

async function checkEnv(logger: Logger) {
  const required = [
    'DATABASE_URL',
    'REDIS_URL',
    'JWT_ACCESS_TOKEN_SECRET',
    'JWT_REFRESH_TOKEN_SECRET',
  ];
  const missing = required.filter((k) => !process.env[k]);
  if (missing.length > 0) {
    logger.warn(`Missing required env variables: ${missing.join(', ')}. The app may not function properly.`);
  }

  // Mercado Pago keys are required for payment flows (sandbox ok)
  const mpKeys = [
    'MERCADOPAGO_PUBLIC_KEY',
    'MERCADOPAGO_ACCESS_TOKEN',
    'MERCADOPAGO_CLIENT_ID',
    'MERCADOPAGO_CLIENT_SECRET',
  ];
  const mpMissing = mpKeys.filter((k) => !process.env[k]);
  if (mpMissing.length > 0) {
    logger.warn(`Mercado Pago env variables not fully set: ${mpMissing.join(', ')}. Payment flows will fail until configured.`);
  }

  if (!process.env.FRONTEND_URL || !process.env.BACKEND_URL) {
    logger.warn('FRONTEND_URL and/or BACKEND_URL not set. Update .env with proper URLs for redirects and webhooks.');
  }

  if (process.env.NODE_ENV === 'production') {
    logger.log('Running in production mode. Ensure HTTPS, domain and production keys are configured.');
  }
}

bootstrap();