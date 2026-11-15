import 'dart:io';

import 'package:path/path.dart' as p;

/// Resolves an attachment only when its canonical path remains inside the
/// application's owned materials directory.
///
/// Backup JSON is untrusted input. Never pass its stored file_path directly to
/// a native document viewer: an imported absolute path or symlink could point
/// at an unrelated local file.
class MaterialPathGuard {
  const MaterialPathGuard({required this.rootDirectory});

  final Directory rootDirectory;

  /// Returns the canonical path for an existing owned file, otherwise null.
  ///
  /// Resolving both paths before checking containment prevents simple
  /// parent-directory traversal and symlink escapes.
  Future<String?> resolveOwnedFilePath(String candidatePath) async {
    if (candidatePath.trim().isEmpty) return null;

    try {
      final rootPath = await rootDirectory.resolveSymbolicLinks();
      final candidate = File(candidatePath);
      if (!await candidate.exists()) return null;

      final candidateResolvedPath = await candidate.resolveSymbolicLinks();
      final normalizedRoot = p.normalize(p.absolute(rootPath));
      final normalizedCandidate =
          p.normalize(p.absolute(candidateResolvedPath));

      if (!p.isWithin(normalizedRoot, normalizedCandidate)) return null;
      return normalizedCandidate;
    } on Object {
      // Missing roots/files, malformed paths and filesystem errors all fail
      // closed. The caller must not attempt to open the original path.
      return null;
    }
  }
}
