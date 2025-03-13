import 'dart:async';
import 'dart:convert';
import 'dart:core';
import 'dart:io' as io;

import 'package:collection/collection.dart';
import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:executor/executor.dart';
import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:get/get_instance/src/extension_instance.dart';
import 'package:get/get_rx/get_rx.dart';
import 'package:get/get_state_manager/src/simple/get_controllers.dart';
import 'package:get/get_utils/get_utils.dart';
import 'package:intl/intl.dart';
import 'package:jhentai/src/database/dao/gallery_dao.dart';
import 'package:jhentai/src/database/dao/gallery_group_dao.dart';
import 'package:jhentai/src/database/database.dart';
import 'package:jhentai/src/exception/eh_image_exception.dart';
import 'package:jhentai/src/exception/eh_parse_exception.dart';
import 'package:jhentai/src/extension/dio_exception_extension.dart';
import 'package:jhentai/src/extension/list_extension.dart';
import 'package:jhentai/src/model/gallery_thumbnail.dart';
import 'package:jhentai/src/model/gallery_url.dart';
import 'package:jhentai/src/service/super_resolution_service.dart';
import 'package:jhentai/src/setting/download_setting.dart';
import 'package:jhentai/src/setting/network_setting.dart';
import 'package:jhentai/src/setting/site_setting.dart';
import 'package:jhentai/src/setting/user_setting.dart';
import 'package:jhentai/src/utils/convert_util.dart';
import 'package:jhentai/src/utils/speed_computer.dart';
import 'package:jhentai/src/service/log.dart';
import 'package:jhentai/src/utils/toast_util.dart';
import 'package:path/path.dart' as path;
import 'package:path/path.dart';
import 'package:retry/retry.dart';
import 'package:drift/drift.dart';
import 'package:jhentai/src/enum/config_type_enum.dart';
import 'package:jhentai/src/service/cloud_service.dart';
import 'package:jhentai/src/widget/loading_state_indicator.dart';
import 'package:jhentai/src/extension/widget_extension.dart' as widget_extension;
import 'package:file_picker/file_picker.dart';
import 'package:jhentai/src/model/config.dart';
import 'package:jhentai/src/service/isolate_service.dart';

import '../consts/locale_consts.dart';
import '../database/dao/gallery_image_dao.dart';
import '../exception/cancel_exception.dart';
import '../exception/eh_site_exception.dart';
import '../model/comic_info.dart';
import '../model/detail_page_info.dart';
import '../model/gallery_detail.dart';
import '../model/gallery_image.dart';
import '../network/eh_request.dart';
import '../pages/download/grid/mixin/grid_download_page_service_mixin.dart';
import 'jh_service.dart';
import 'path_service.dart';
import '../utils/eh_executor.dart';
import '../utils/eh_spider_parser.dart';
import '../utils/snack_util.dart';
import 'package:webdav_client/webdav_client.dart' as webdav_client;

/// Responsible for local images meta-data and download all images of a gallery
WebDAVService webdavService = WebDAVService();

class WebDAVService extends GetxController with JHLifeCircleBeanErrorCatch implements JHLifeCircleBean {
  webdav_client.Client? webdavClient;
  bool _exportDataLoadingState = false;
  bool _importDataLoadingState = false;
  String webdavCachePath='';
  String webdavCacheJsonPath='';
  String webdavRemotePath='/JHentaiData';

  @override
  Future<void> doInitBean() async {
    Get.put(this, permanent: true);
    webdavClient=webdav_client.newClient(networkSetting.webdavURL.value ?? '', user: networkSetting.webdavUserName.value ?? '', password: networkSetting.webdavPassword.value ?? '');
    await webdavClient?.mkdir('/JHentaiData');
    final directory = io.Directory.current;
    webdavCachePath = '${directory.path}/cache';
    webdavCacheJsonPath = '$webdavCachePath/${CloudConfigService.configFileName}-WebDAV.json';
  }

  @override
  Future<void> doAfterBeanReady() async {}


  Future<void> testSynchronize() async {
    try {
      await webdavClient?.ping();
      var list = await webdavClient?.readDir('/');
      list?.forEach((f) {
        print('${f.path}');
      });
      toast('success'.tr);
    } catch (e) {
      log.info('$e');
      toast('fail'.tr);
    }
  }

  Future<void> webdavUploadData() async {
    try {
      await webdavClient?.mkdir(webdavRemotePath);
      await _exportData();
      if(await io.File(webdavCacheJsonPath).exists()){
        await webdavClient?.writeFromFile(webdavCacheJsonPath, '$webdavRemotePath/${CloudConfigService.configFileName}-WebDAV.json', cancelToken:CancelToken());
      }
    } catch (e) {
      log.info('$e');
    }
  }
  Future<void> webdavDownloadData() async {
    try {
      await _createCache();
      await webdavClient?.read2File('$webdavRemotePath/${CloudConfigService.configFileName}-WebDAV.json', webdavCacheJsonPath);
      if (await io.File(webdavCacheJsonPath).exists()) {
        _importData();
      }
    } catch (e) {
      log.info('$e');
    }
  }

  Future<void> _importData() async {

    if (_importDataLoadingState) {
      return;
    }

    log.info('Import data from $webdavCacheJsonPath');
    _importDataLoadingState = true;


    try {
      io.File file = io.File(webdavCacheJsonPath);
      String string = await file.readAsString();
      List list = await isolateService.jsonDecodeAsync(string);
      List<CloudConfig> configs = list.map((e) => CloudConfig.fromJson(e)).toList();
      for (CloudConfig config in configs) {
        await cloudConfigService.importConfig(config);
      }
      log.info('success'.tr);
      _importDataLoadingState = false;
    } catch (e, s) {
      log.error('Import data failed', e, s);
      log.info('internalError'.tr);
      _importDataLoadingState = false;
      return;
    }
  }

  Future<void> _exportData() async {
    List<CloudConfigTypeEnum> result = [CloudConfigTypeEnum.blockRules,CloudConfigTypeEnum.history,CloudConfigTypeEnum.quickSearch,CloudConfigTypeEnum.readIndexRecord,CloudConfigTypeEnum.searchHistory];

    String fileName = '${CloudConfigService.configFileName}-WebDAV.json';
    if (GetPlatform.isMobile) {
      return _exportDataMobile(fileName, result);
    } else {
      return _exportDataDesktop(fileName, result);
    }
  }

  Future<void> _createCache() async {
      // cache目录如果不存在，则创建目录
      final cacheDirectory = io.Directory(webdavCachePath);
      if (!await cacheDirectory.exists()) {
        await cacheDirectory.create(recursive: true);
      } 
  }

  Future<void> _exportDataMobile(String fileName, List<CloudConfigTypeEnum>? result) async {
    if (_exportDataLoadingState) {
      return;
    }
    _exportDataLoadingState = true;

    List<CloudConfig> uploadConfigs = [];
    for (CloudConfigTypeEnum type in result!) {
      CloudConfig? config = await cloudConfigService.getLocalConfig(type);
      if (config != null) {
        uploadConfigs.add(config);
      }
    }
    try {
      await _createCache();
      final file = io.File(webdavCacheJsonPath);
      await file.writeAsString(await isolateService.jsonEncodeAsync(uploadConfigs));
      if (await io.File(webdavCacheJsonPath).exists()) {
        log.info('Export data to $webdavCacheJsonPath success');
        log.info('success'.tr);
        _exportDataLoadingState = false;
      }
    } on Exception catch (e) {
      log.error('Export data failed', e);
      log.info('internalError'.tr);
      _exportDataLoadingState = false;
    }
  }

  Future<void> _exportDataDesktop(String fileName, List<CloudConfigTypeEnum>? result) async {
    if (_exportDataLoadingState) {
      return;
    }
    _exportDataLoadingState = true;
    try {
      await _createCache();
    } on Exception catch (e) {
      log.error('Select save path for exporting data failed', e);
      log.info('internalError'.tr);
      _exportDataLoadingState = false;
      return;
    }

    List<CloudConfig> uploadConfigs = [];
    for (CloudConfigTypeEnum type in result!) {
      CloudConfig? config = await cloudConfigService.getLocalConfig(type);
      if (config != null) {
        uploadConfigs.add(config);
      }
    }

    io.File file = io.File(webdavCacheJsonPath);
    try {
      if (await file.exists()) {
        await file.create(recursive: true);
      }
      await file.writeAsString(await isolateService.jsonEncodeAsync(uploadConfigs));
      log.info('Export data to $webdavCacheJsonPath success');
      log.info('success'.tr);
      _exportDataLoadingState = false;
    } on Exception catch (e) {
      log.error('Export data failed', e);
      log.info('internalError'.tr);
      _exportDataLoadingState = false;
      file.delete().ignore();
    }
  }
}