import { ValidationPipe } from '@nestjs/common';
import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';

async function bootstrap(): Promise<void> {
  const app = await NestFactory.create(AppModule);
  app.setGlobalPrefix('api/v1');
  app.enableCors(); // allow the Flutter web build / admin to call the API
  app.useGlobalPipes(
    new ValidationPipe({ whitelist: true, transform: true, forbidNonWhitelisted: false }),
  );
  const port = process.env.PORT ? Number(process.env.PORT) : 3000;
  await app.listen(port, '0.0.0.0'); // bind all interfaces (emulator/LAN device reachable)
  // eslint-disable-next-line no-console
  console.log(`DPOS API listening on http://0.0.0.0:${port}/api/v1`);
}

void bootstrap();
