import 'dart:convert';
import 'dart:io';

import 'package:get/get.dart';
import 'package:jhentai/src/consts/eh_consts.dart';
import 'package:jhentai/src/enum/config_enum.dart';
import 'package:jhentai/src/service/path_service.dart';
import 'package:jhentai/src/service/log.dart';
import 'package:path/path.dart';

import '../service/jh_service.dart';
import '../utils/toast_util.dart';

DownloadSetting downloadSetting = DownloadSetting();

class DownloadSetting with JHLifeCircleBeanWithConfigStorage implements JHLifeCircleBean {
  late String defaultDownloadPath;
  late RxString downloadPath;
  RxBool downloadOriginalImageByDefault = false.obs;
  RxBool downloadWithoutAsking = true.obs;
  RxnString defaultGalleryGroup = RxnString();
  RxnString defaultArchiveGroup = RxnString();
  late String defaultExtraGalleryScanPath;
  late RxList<String> extraGalleryScanPath;
  late RxString singleImageSavePath;
  late RxString tempDownloadPath;
  RxInt downloadTaskConcurrency = 6.obs;
  RxInt maximum = 2.obs;
  Rx<Duration> period = const Duration(seconds: 1).obs;
  RxBool downloadAllGallerysOfSamePriority = false.obs;
  RxInt archiveDownloadIsolateCount = 1.obs;
  RxBool manageArchiveDownloadConcurrency = true.obs;
  RxBool deleteArchiveFileAfterDownload = true.obs;
  RxBool restoreTasksAutomatically = false.obs;

  @override
  ConfigEnum get configEnum => ConfigEnum.downloadSetting;

  @override
  void applyBeanConfig(String configString) {
    Map map = jsonDecode(configString);

    if (!GetPlatform.isIOS) {
      downloadPath.value = map['downloadPath'] ?? downloadPath.value;
      singleImageSavePath.value = map['singleImageSavePath'] ?? singleImageSavePath.value;
    }
    if (map['extraGalleryScanPath'] != null) {
      extraGalleryScanPath.addAll(map['extraGalleryScanPath'].cast<String>());
      extraGalleryScanPath.value = extraGalleryScanPath.toSet().toList();
    }
    downloadOriginalImageByDefault.value = map['downloadOriginalImageByDefault'] ?? downloadOriginalImageByDefault.value;
    downloadWithoutAsking.value = map['downloadWithoutAsking'] ?? downloadWithoutAsking.value;
    defaultGalleryGroup.value = map['defaultGalleryGroup'];
    defaultArchiveGroup.value = map['defaultArchiveGroup'];
    downloadTaskConcurrency.value = map['downloadTaskConcurrency'];
    maximum.value = map['maximum'];
    period.value = Duration(milliseconds: map['period']);
    downloadAllGallerysOfSamePriority.value = map['downloadAllGallerysOfSamePriority'] ?? downloadAllGallerysOfSamePriority.value;
    archiveDownloadIsolateCount.value = map['archiveDownloadIsolateCount'] ?? archiveDownloadIsolateCount.value;
    if (archiveDownloadIsolateCount.value > 10) {
      archiveDownloadIsolateCount.value = 10;
    }
    manageArchiveDownloadConcurrency.value = map['manageArchiveDownloadConcurrency'] ?? manageArchiveDownloadConcurrency.value;
    deleteArchiveFileAfterDownload.value = map['deleteArchiveFileAfterDownload'] ?? deleteArchiveFileAfterDownload.value;
    restoreTasksAutomatically.value = map['restoreTasksAutomatically'] ?? restoreTasksAutomatically.value;
  }

  @override
  String toConfigString() {
    return jsonEncode({
      'downloadPath': downloadPath.value,
      'extraGalleryScanPath': extraGalleryScanPath.value,
      'singleImageSavePath': singleImageSavePath.value,
      'downloadOriginalImageByDefault': downloadOriginalImageByDefault.value,
      'downloadWithoutAsking': downloadWithoutAsking.value,
      'defaultGalleryGroup': defaultGalleryGroup.value,
      'defaultArchiveGroup': defaultArchiveGroup.value,
      'downloadTaskConcurrency': downloadTaskConcurrency.value,
      'maximum': maximum.value,
      'period': period.value.inMilliseconds,
      'downloadAllGallerysOfSamePriority': downloadAllGallerysOfSamePriority.value,
      'archiveDownloadIsolateCount': archiveDownloadIsolateCount.value,
      'manageArchiveDownloadConcurrency': manageArchiveDownloadConcurrency.value,
      'deleteArchiveFileAfterDownload': deleteArchiveFileAfterDownload.value,
      'restoreTasksAutomatically': restoreTasksAutomatically.value,
    });
  }

  @override
  Future<void> doInitBean() async {
    defaultDownloadPath = join(pathService.getVisibleDir().path, 'download');
    downloadPath = defaultDownloadPath.obs;
    defaultExtraGalleryScanPath = join(pathService.getVisibleDir().path, 'local_gallery');
    extraGalleryScanPath = <String>[defaultExtraGalleryScanPath].obs;
    singleImageSavePath = join(pathService.getVisibleDir().path, 'save').obs;
    tempDownloadPath = join(pathService.tempDir.path, EHConsts.appName).obs;

    await _ensureDownloadDirExists();
    await _clearTempDownloadPath();
  }

  @override
  void doAfterBeanReady() {}

  Future<void> saveDownloadPath(String downloadPath) async {
    log.debug('saveDownloadPath:$downloadPath');
    this.downloadPath.value = downloadPath;
    await saveBeanConfig();
  }

  Future<void> addExtraGalleryScanPath(String newPath) async {
    log.debug('addExtraGalleryScanPath:$newPath');
    extraGalleryScanPath.add(newPath);
    await saveBeanConfig();
  }

  Future<void> removeExtraGalleryScanPath(String path) async {
    log.debug('removeExtraGalleryScanPath:$path');
    extraGalleryScanPath.remove(path);
    await saveBeanConfig();
  }

  Future<void> saveSingleImageSavePath(String singleImageSavePath) async {
    log.debug('saveSingleImageSavePath:$singleImageSavePath');
    this.singleImageSavePath.value = singleImageSavePath;
    await saveBeanConfig();
  }

  Future<void> saveDownloadOriginalImageByDefault(bool value) async {
    log.debug('saveDownloadOriginalImageByDefault:$value');
    this.downloadOriginalImageByDefault.value = value;
    await saveBeanConfig();
  }

  Future<void> saveDownloadWithoutAsking(bool value) async {
    log.debug('saveDownloadWithoutAskingByDefault:$value');
    this.downloadWithoutAsking.value = value;
    await saveBeanConfig();
  }

  Future<void> saveDefaultGalleryGroup(String? group) async {
    log.debug('saveDefaultGalleryGroup:$group');
    this.defaultGalleryGroup.value = group;
    await saveBeanConfig();
  }

  Future<void> saveDefaultArchiveGroup(String? group) async {
    log.debug('saveDefaultArchiveGroup:$group');
    this.defaultArchiveGroup.value = group;
    await saveBeanConfig();
  }

  Future<void> saveDownloadTaskConcurrency(int downloadTaskConcurrency) async {
    log.debug('saveDownloadTaskConcurrency:$downloadTaskConcurrency');
    this.downloadTaskConcurrency.value = downloadTaskConcurrency;
    await saveBeanConfig();
  }

  Future<void> saveMaximum(int maximum) async {
    log.debug('saveMaximum:$maximum');
    this.maximum.value = maximum;
    await saveBeanConfig();
  }

  Future<void> savePeriod(Duration period) async {
    log.debug('savePeriod:$period');
    this.period.value = period;
    await saveBeanConfig();
  }

  Future<void> saveDownloadAllGallerysOfSamePriority(bool value) async {
    log.debug('saveDownloadAllGallerysOfSamePriority:$value');
    downloadAllGallerysOfSamePriority.value = value;
    await saveBeanConfig();
  }

  Future<void> saveArchiveDownloadIsolateCount(int count) async {
    log.debug('saveArchiveDownloadIsolateCount:$count');
    archiveDownloadIsolateCount.value = count;
    await saveBeanConfig();
  }

  Future<void> saveManageArchiveDownloadConcurrency(bool value) async {
    log.debug('saveManageArchiveDownloadConcurrency:$value');
    manageArchiveDownloadConcurrency.value = value;
    await saveBeanConfig();
  }

  Future<void> saveDeleteArchiveFileAfterDownload(bool value) async {
    log.debug('saveDeleteArchiveFileAfterDownload:$value');
    deleteArchiveFileAfterDownload.value = value;
    await saveBeanConfig();
  }

  Future<void> saveRestoreTasksAutomatically(bool value) async {
    log.debug('saveRestoreTasksAutomatically:$value');
    restoreTasksAutomatically.value = value;
    await saveBeanConfig();
  }

  Future<void> _ensureDownloadDirExists() async {
    try {
      await Directory(downloadPath.value).create(recursive: true);
      await Directory(defaultExtraGalleryScanPath).create(recursive: true);
      await Directory(singleImageSavePath.value).create(recursive: true);
    } on Exception catch (e) {
      toast('brokenDownloadPathHint'.tr);
      log.error(e);
      log.uploadError(
        e,
        extraInfos: {
          'defaultDownloadPath': this.defaultDownloadPath,
          'downloadPath': this.downloadPath.value,
          'exists': pathService.getVisibleDir().existsSync(),
        },
      );
    }
  }

  Future<void> _clearTempDownloadPath() async {
    try {
      Directory directory = Directory(tempDownloadPath.value);
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
      await Directory(tempDownloadPath.value).create();
    } on Exception catch (e) {
      log.error(e);
    }
  }
}
