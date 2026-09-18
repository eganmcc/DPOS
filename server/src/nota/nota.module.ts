import { Logger, Module } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { NotaController } from './nota.controller';
import { NotaService } from './nota.service';
import { NOTA_VISION_PROVIDER, NotaVisionProvider } from './vision/nota-vision.provider';
import { ClaudeNotaVisionProvider } from './vision/claude.provider';
import { StubNotaVisionProvider } from './vision/stub.provider';

/**
 * Measured on 2026-09-18 against a test nota (scripts/bench-nota-vision.ts): Opus 5 at medium
 * effort with thinking off read it correctly in ~3.3s, against ~11.9s for Sonnet 5 at the API's
 * default high effort with thinking on — and the thinking runs were the ones that invented a
 * 0 for a line with no amount. Reading a slip is perception, not deduction. Override per
 * environment with NOTA_VISION_MODEL / NOTA_VISION_EFFORT / NOTA_VISION_THINKING.
 */
const DEFAULT_MODEL = 'claude-opus-5';
const DEFAULT_EFFORT = 'medium';

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
        const effort = (config.get<string>('NOTA_VISION_EFFORT') ?? DEFAULT_EFFORT) as
          | 'low'
          | 'medium'
          | 'high'
          | 'xhigh'
          | 'max';
        // Thinking is off unless explicitly asked for; it tripled the wait for no gain here.
        const thinkingDisabled = config.get<string>('NOTA_VISION_THINKING') !== 'adaptive';
        new Logger('NotaModule').log(
          `Nota reader: ${model} · effort ${effort} · thinking ${thinkingDisabled ? 'off' : 'adaptive'}`,
        );
        return new ClaudeNotaVisionProvider(apiKey, model, effort, thinkingDisabled);
      },
    },
  ],
})
export class NotaModule {}
