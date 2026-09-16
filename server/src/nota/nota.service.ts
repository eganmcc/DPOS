import { Inject, Injectable, Logger, UnsupportedMediaTypeException } from '@nestjs/common';
import {
  NOTA_VISION_PROVIDER,
  NotaReadResult,
  NotaVisionProvider,
} from './vision/nota-vision.provider';

/** Magic bytes per accepted format. A declared Content-Type is a claim, not evidence. */
const SIGNATURES: { mime: string; test: (b: Buffer) => boolean }[] = [
  { mime: 'image/jpeg', test: (b) => b[0] === 0xff && b[1] === 0xd8 && b[2] === 0xff },
  {
    mime: 'image/png',
    test: (b) => b.subarray(0, 8).equals(Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a])),
  },
  {
    mime: 'image/webp',
    test: (b) => b.subarray(0, 4).toString('ascii') === 'RIFF' && b.subarray(8, 12).toString('ascii') === 'WEBP',
  },
];

/**
 * Reads a photographed nota and returns what it says.
 *
 * Deliberately stateless: the image is held in memory for the length of one request and dropped.
 * Nothing is stored, no sale is created and no stock moves — this slice exists to answer whether
 * the reading is good enough to build on.
 */
@Injectable()
export class NotaService {
  private readonly logger = new Logger(NotaService.name);

  constructor(@Inject(NOTA_VISION_PROVIDER) private readonly vision: NotaVisionProvider) {}

  /** The format we can actually send onward, decided from the bytes rather than the header. */
  private sniff(image: Buffer): string {
    const match = SIGNATURES.find((s) => image.length > 12 && s.test(image));
    if (!match) {
      throw new UnsupportedMediaTypeException({
        code: 'NOTA_UNSUPPORTED_IMAGE',
        message: 'Upload a JPEG, PNG or WebP photo.',
      });
    }
    return match.mime;
  }

  async read(image: Buffer): Promise<NotaReadResult> {
    const mimeType = this.sniff(image);
    const startedAt = Date.now();
    const extraction = await this.vision.extract(image, mimeType);
    const latencyMs = Date.now() - startedAt;

    this.logger.log(
      `nota read via ${this.vision.name}: ${extraction.items.length} line(s), ` +
        `confidence ${extraction.confidence}, ${latencyMs}ms, ${image.length} bytes`,
    );

    return { ...extraction, model: this.vision.name, latencyMs };
  }
}
