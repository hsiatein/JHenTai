import 'dart:async';
import 'dart:core';
import 'dart:io' as io;

import 'package:dio/dio.dart';

import 'package:get/get_core/src/get_main.dart';
import 'package:get/get_instance/src/extension_instance.dart';
import 'package:get/get_state_manager/src/simple/get_controllers.dart';
import 'package:get/get_utils/get_utils.dart';
import 'package:jhentai/src/service/storage_service.dart';

import 'package:jhentai/src/setting/network_setting.dart';

import 'package:jhentai/src/service/log.dart';
import 'package:jhentai/src/utils/toast_util.dart';

import 'package:jhentai/src/enum/config_type_enum.dart';
import 'package:jhentai/src/service/cloud_service.dart';

import 'package:jhentai/src/model/config.dart';
import 'package:jhentai/src/service/isolate_service.dart';

import 'jh_service.dart';
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
  bool enable=false;

  @override
  Future<void> doInitBean() async {
    enable=networkSetting.enableWebDAV.value;
    if(enable){
      Get.put(this, permanent: true);
      webdavClient=webdav_client.newClient(networkSetting.webdavURL.value ?? '', user: networkSetting.webdavUserName.value ?? '', password: networkSetting.webdavPassword.value ?? '');
      await webdavClient?.mkdir('/JHentaiData');
      final directory = io.Directory.current;
      webdavCachePath = '${directory.path}/cache';
      webdavCacheJsonPath = '$webdavCachePath/${CloudConfigService.configFileName}-WebDAV.json';
    }
  }

  @override
  Future<void> doAfterBeanReady() async {}


  Future<void> testSynchronize() async {
    if(enable){
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
  }

  Future<void> webdavUploadData() async {
    if(enable){
      try {
        await webdavClient?.mkdir(webdavRemotePath);
        await _exportData();
        if(await io.File(webdavCacheJsonPath).exists()){
          await webdavClient?.writeFromFile(webdavCacheJsonPath, '$webdavRemotePath/${CloudConfigService.configFileName}-WebDAV.json', cancelToken:CancelToken());
        }
        log.info('同步成功');
      } catch (e) {
        log.info('$e');
      }
    }
  }
  Future<void> webdavDownloadData() async {
    if(enable){
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