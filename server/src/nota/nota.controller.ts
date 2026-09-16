import {
  BadRequestException,
  Controller,
  HttpCode,
  Post,
  UploadedFile,
  UseGuards,
  UseInterceptors,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { AuthGuard } from '../auth/auth.guard';
import { NotaService } from './nota.service';
import { NotaReadResult } from './vision/nota-vision.provider';

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
  async read(@UploadedFile() file?: Express.Multer.File): Promise<NotaReadResult> {
    if (!file?.buffer?.length) {
      throw new BadRequestException({
        code: 'NOTA_NO_IMAGE',
        message: 'Attach a photo of the nota as "file".',
      });
    }
    return this.nota.read(file.buffer);
  }
}
