import 'dart:io';

import 'package:daftar/core/errors/failures.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:fpdart/fpdart.dart';
import 'package:path/path.dart' as p;

/// Compresses merchant logo picks via native codecs into a deterministic JPEG.
abstract final class MerchantLogoImageProcessor {
  /// Maximum width or height in pixels (native resize target).
  static const int maxDimension = 512;

  /// Maximum output file size in bytes.
  static const int maxFileBytes = 200 * 1024;

  /// Initial JPEG encode quality (0–100).
  static const int initialJpegQuality = 80;

  /// Deterministic logo filename under the app documents directory.
  static const String outputFileName = 'merchant_logo.jpg';

  /// Compresses [sourcePath] natively and writes [outputFileName], overwriting prior logos.
  static Future<Either<Failure, String>> writeOptimizedLogo({
    required String sourcePath,
    required Directory documentsDirectory,
  }) async {
    final trimmedSource = sourcePath.trim();
    if (trimmedSource.isEmpty) {
      return const Left(
        ValidationFailure(
          'Logo source path is required.',
          code: 'merchant_logo_source_required',
        ),
      );
    }

    try {
      final sourceFile = File(trimmedSource);
      if (!sourceFile.existsSync()) {
        return const Left(
          StorageFailure(
            'Logo file not found.',
            code: 'merchant_logo_source_not_found',
          ),
        );
      }

      final targetPath = p.join(documentsDirectory.path, outputFileName);
      final targetFile = File(targetPath);
      await targetFile.parent.create(recursive: true);
      if (targetFile.existsSync()) {
        await targetFile.delete();
      }

      var quality = initialJpegQuality;
      XFile? compressed;

      while (quality >= 40) {
        compressed = await FlutterImageCompress.compressAndGetFile(
          sourceFile.absolute.path,
          targetPath,
          minWidth: maxDimension,
          minHeight: maxDimension,
          quality: quality,
        );

        if (compressed == null) {
          return const Left(
            ValidationFailure(
              'Logo image format is not supported.',
              code: 'merchant_logo_compress_failed',
            ),
          );
        }

        final output = File(compressed.path);
        if (!output.existsSync()) {
          return const Left(
            StorageFailure(
              'Compressed logo file was not created.',
              code: 'merchant_logo_output_missing',
            ),
          );
        }

        if (output.lengthSync() <= maxFileBytes) {
          return Right(output.absolute.path);
        }

        await output.delete();
        quality -= 10;
      }

      return const Left(
        ValidationFailure(
          'Logo could not be compressed below 200KB.',
          code: 'merchant_logo_size_exceeded',
        ),
      );
    } on FileSystemException catch (error) {
      return Left(
        StorageFailure(
          'Failed to store merchant logo: ${error.message}',
          code: 'merchant_logo_io_error',
        ),
      );
    } on Object catch (error) {
      return Left(
        StorageFailure(
          'Failed to process merchant logo: $error',
          code: 'merchant_logo_process_error',
        ),
      );
    }
  }
}
