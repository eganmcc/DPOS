import {
  BadRequestException,
  Controller,
  ForbiddenException,
  HttpCode,
  Post,
  Query,
  Req,
  UploadedFile,
  UseGuards,
  UseInterceptors,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { Request } from 'express';
import { AuthGuard } from '../auth/auth.guard';
import { NotaService } from './nota.service';
import { EVALUATION_MODELS, NotaReadResult } from './vision/nota-vision.provider';

/** A phone photo downscaled to 1600px lands around 150-400 kB; 6 MB is generous headroom. */
const MAX_IMAGE_BYTES = 6 * 1024 * 1024;

@Controller('nota')
@UseGuards(AuthGuard)
export class NotaController {
  constructor(private readonly nota: NotaService) {}

  /**
   * Read a photographed nota and return what it says.
   *
   * Stateless by design: nothing is persisted, no order is created and no stock moves. The image
   * is held in memory for this request only.
   */
  @Post('read')
  @HttpCode(200)
  @UseInterceptors(
    FileInterceptor('file', {
      limits: { fileSize: MAX_IMAGE_BYTES, files: 1 },
    }),
  )
  async read(
    @Req() req: Request,
    @UploadedFile() file?: Express.Multer.File,
    /**
     * `?model=` reads this one slip with a different model, for comparing them on real
     * handwriting — the only evidence that can decide which model to run, and impossible to get
     * from a synthetic page. Owner-only and allowlisted, because choosing the model chooses the
     * bill. The app never sends it; the configured reader is used when it is absent.
     */
    @Query('model') model?: string,
  ): Promise<NotaReadResult> {
    if (!file?.buffer?.length) {
      throw new BadRequestException({
        code: 'NOTA_NO_IMAGE',
        message: 'Attach a photo of the nota as "file".',
      });
    }
    if (model !== undefined) {
      const user = (req as Request & { user?: { role?: string } }).user;
      if (user?.role !== 'OWNER') {
        throw new ForbiddenException({
          code: 'NOTA_MODEL_OVERRIDE_FORBIDDEN',
          message: 'Only an owner may choose the reader model.',
        });
      }
      if (!(EVALUATION_MODELS as readonly string[]).includes(model)) {
        throw new BadRequestException({
          code: 'NOTA_MODEL_NOT_ALLOWED',
          message: `model must be one of: ${EVALUATION_MODELS.join(', ')}`,
        });
      }
    }
    return this.nota.read(file.buffer, model);
  }
}
