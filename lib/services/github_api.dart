import 'dart:developer';
import 'dart:io';
import 'package:collection/collection.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';
import 'package:revanced_manager/app/app.locator.dart';
import 'package:revanced_manager/services/download_manager.dart';
import 'package:revanced_manager/services/manager_api.dart';
import 'package:revanced_manager/services/toast.dart';

@lazySingleton
class GithubAPI {
  late final Dio _dio;
  late final ManagerAPI _managerAPI = locator<ManagerAPI>();
  late final DownloadManager _downloadManager = locator<DownloadManager>();

  Future<void> initialize(String repoUrl) async {
    _dio = _downloadManager.initDio(repoUrl);
  }

  Future<void> clearAllCache() async {
    await _downloadManager.clearAllCache();
  }

  Future<Map<String, dynamic>?> getLatestRelease(
    String repoName,
  ) async {
    final Toast _toast = locator<Toast>();

    try {
      log('[getLatestRelease()] Trying to get latest release ($repoName)');
      final response = await _dio.get(
        '/repos/$repoName/releases/latest',
      );
      return response.data;
    } on Exception catch (e) {
      if (kDebugMode) {
        log('possible rate limit ($repoName)');
        log(e.toString());
        print(e);
      }
      _toast.showBottom('settingsView.rateLimited');
      return null;
    }
  }

  Future<Map<String, dynamic>?> getLatestPreRelease(String repoName) async {
    final Toast _toast = locator<Toast>();
    try {
      log('[getLatestPreRelease()] Trying to get the latest PRE-release ($repoName)');
      final Response response = await _dio.get('/repos/$repoName/releases');
      final List<dynamic> releases = response.data;

      if (releases.isEmpty) {
        log('No releases found ($repoName), no absolute releases...');
        throw Exception('No releases found ($repoName)');
      }

      Map<String, dynamic>? latestPreRelease;
      DateTime latestPreReleaseDate = DateTime.fromMillisecondsSinceEpoch(0);

      for (final release in releases) {
        if (release['prerelease'] == true) {
          final DateTime releaseDate = DateTime.parse(release['published_at']);
          if (releaseDate.isAfter(latestPreReleaseDate)) {
            latestPreReleaseDate = releaseDate;
            latestPreRelease = release;
          }
        }
      }

      if (latestPreRelease == null) {
        log('No PRE-release found ($repoName)');
        throw Exception('No PRE-release found ($repoName)');
      }

      return latestPreRelease;
    } catch (e) {
      if (kDebugMode) {
        log('possible rate limit ($repoName)');
        print(e);
      }
      _toast.showBottom('settingsView.rateLimited');
      return null;
    }
  }

  Future<Map<String, dynamic>?> getPatchesRelease(
    String repoName,
    String version,
  ) async {
    Toast _toast = locator<Toast>();
    try {
      final response = await _dio.get(
        '/repos/$repoName/releases/tags/$version',
      );
      return response.data;
    } on Exception catch (e) {
      if (kDebugMode) {
        log('possible rate limit ($repoName)');
        print(e);
      }
      _toast.showBottom('settingsView.rateLimited');
      return null;
    }
  }

  Future<Map<String, dynamic>?> getLatestPatchesRelease(
    String repoName,
  ) async {
    Toast _toast = locator<Toast>();
    try {
      final response = await _dio.get(
        '/repos/$repoName/releases/latest',
      );
      return response.data;
    } on Exception catch (e) {
      if (kDebugMode) {
        log('possible rate limit ($repoName)');
        print(e);
      }
      _toast.showBottom('settingsView.rateLimited');
      return null;
    }
  }

  Future<Map<String, dynamic>?> getLatestManagerRelease(
    String repoName,
  ) async {
    Toast _toast = locator<Toast>();
    try {
      final response = await _dio.get(
        '/repos/$repoName/releases',
      );
      final Map<String, dynamic> releases = response.data[0];
      int updates = 0;
      final String currentVersion =
          await _managerAPI.getCurrentManagerVersion();
      while (response.data[updates]['tag_name'] != 'v$currentVersion') {
        updates++;
      }
      for (int i = 1; i < updates; i++) {
        releases.update(
          'body',
          (value) =>
              value +
              '\n' +
              '# ' +
              response.data[i]['tag_name'] +
              '\n' +
              response.data[i]['body'],
        );
      }
      return releases;
    } on Exception catch (e) {
      if (kDebugMode) {
        log('possible rate limit ($repoName)');
        print(e);
      }
      _toast.showBottom('settingsView.rateLimited');
      return null;
    }
  }

  Future<File?> getLatestReleaseFile(
    String extension,
    String repoName,
  ) async {
    try {
      //log('isPreReleasesEnabled? ${_managerAPI.isPreReleasesEnabled()}');
      final Map<String, dynamic>? release;
      if (_managerAPI.isPreReleasesEnabled()) {
        release = await getLatestPreRelease(repoName);
      } else {
        release = await getLatestRelease(repoName);
      }
      if (release != null) {
        final Map<String, dynamic>? asset =
            (release['assets'] as List<dynamic>).firstWhereOrNull(
          (asset) => (asset['name'] as String).endsWith(extension),
        );
        if (asset != null) {
          return await _downloadManager.getSingleFile(
            asset['browser_download_url'],
          );
        }
      }
    } on Exception catch (e) {
      if (kDebugMode) {
        log('possible rate limit ($repoName)');
        print(e);
      }
    }
    return null;
  }

  Future<File?> getPatchesReleaseFile(
    String extension,
    String repoName,
    String version,
    String url,
  ) async {
    try {
      if (url.isNotEmpty) {
        return await _downloadManager.getSingleFile(
          url,
        );
      }
      final Map<String, dynamic>? release =
          await getPatchesRelease(repoName, version);
      if (release != null) {
        final Map<String, dynamic>? asset =
            (release['assets'] as List<dynamic>).firstWhereOrNull(
          (asset) => (asset['name'] as String).endsWith(extension),
        );
        if (asset != null) {
          final String downloadUrl = asset['browser_download_url'];
          if (extension == '.apk') {
            _managerAPI.setIntegrationsDownloadURL(downloadUrl);
          } else {
            _managerAPI.setPatchesDownloadURL(downloadUrl);
          }
          return await _downloadManager.getSingleFile(
            downloadUrl,
          );
        }
      }
    } on Exception catch (e) {
      if (kDebugMode) {
        print(e);
      }
    }
    return null;
  }
}
