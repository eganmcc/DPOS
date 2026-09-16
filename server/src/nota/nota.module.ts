import { Logger, Module } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { NotaController } from './nota.controller';
import { NotaService } from './nota.service';
import { NOTA_VISION_PROVIDER, NotaVisionProvider } from './vision/nota-vision.provider';
import { ClaudeNotaVisionProvider } from './vision/claude.provider';
import { StubNotaVisionProvider } from './vision/stub.provider';

/** User's choice for this feature; override per environment without touching code. */
const DEFAULT_MODEL = 'claude-sonnet-5';

@Module({
  controllers: [NotaController],
  providers: [
    NotaService,
    StubNotaVisionProvider,
    {
      provide: NOTA_VISION_PROVIDER,
      inject: [ConfigService, StubNotaVisionProvider],
      /**
       * The stub is the default, and that is load-bearing rather than lazy: with no key present
       * — CI, a fresh clone, the test suite — the nota endpoint still works end to end and cannot
       * spend money. Reading for real is opt-in via `ANTHROPIC_API_KEY`, or forced off with
       * `NOTA_VISION_PROVIDER=stub`.
       */
      useFactory: (config: ConfigService, stub: StubNotaVisionProvider): NotaVisionProvider => {
        const apiKey = config.get<string>('ANTHROPIC_API_KEY');
        const forced = config.get<string>('NOTA_VISION_PROVIDER');
        if (forced === 'stub' || !apiKey) {
          new Logger('NotaModule').log(
            forced === 'stub'
              ? 'Nota reader: stub (forced by NOTA_VISION_PROVIDER)'
              : 'Nota reader: stub (no ANTHROPIC_API_KEY set)',
          );
          return stub;
        }
        const model = config.get<string>('NOTA_VISION_MODEL') ?? DEFAULT_MODEL;
        new Logger('NotaModule').log(`Nota reader: ${model}`);
        return new ClaudeNotaVisionProvider(apiKey, model);
      },
    },
  ],
})
export class NotaModule {}
