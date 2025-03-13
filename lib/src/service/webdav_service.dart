import 'dart:async';
import 'dart:core';
import 'dart:io' as io;

import 'package:dio/dio.dart';

import 'package:get/get_core/src/get_main.dart';
import 'package:get/get_instance/src/extension_instance.dart';
import 'package:get/get_rx/get_rx.dart';
import 'package:get/get_state_manager/src/simple/get_controllers.dart';
import 'package:get/get_utils/get_utils.dart';

import 'package:jhentai/src/setting/network_setting.dart';

import 'package:jhentai/src/service/log.dart';
import 'package:jhentai/src/utils/toast_util.dart';

import 'package:jhentai/src/enum/config_type_enum.dart';
import 'package:jhentai/src/service/cloud_service.dart';

import 'package:jhentai/src/model/config.dart';
import 'package:jhentai/src/service/isolate_service.dart';

import 'jh_service.dart';
import 'package:webdav_client/webdav_client.dart' as webdav_client;
import 'package:jhentai/src/setting/download_setting.dart';
import 'package:path/path.dart' as path;
import 'package:archive/archive_io.dart';

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
  bool enableGallery=false;
  

  @override
  Future<void> doInitBean() async {
    enable=networkSetting.enableWebDAV.value;
    enableGallery=networkSetting.enableWebDAVSynchronizeGallery.value;
    if(enable){
      Get.put(this, permanent: true);
      webdavClient=webdav_client.newClient(networkSetting.webdavURL.value ?? '', user: networkSetting.webdavUserName.value ?? '', password: networkSetting.webdavPassword.value ?? '', debug:true);
      // 设置公共请求头
      webdavClient?.setHeaders({'accept-charset': 'utf-8'});
      // 设置连接服务器超时时间（毫秒）
      webdavClient?.setConnectTimeout(8000);
      // 设置发送数据超时时间（毫秒）
      webdavClient?.setSendTimeout(8000);
      // 设置接收数据超时时间（毫秒）
      webdavClient?.setReceiveTimeout(8000);
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
        log.info(webdavClient?.uri??'');
        log.info(webdavClient?.auth.user??'');
        log.info(webdavClient?.auth.pwd??'');
        await webdavClient?.ping();
        var list = await webdavClient?.readDir('/JHentaiData/');
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

  Future<void> webdavUploadAllGalleries() async {
    if(enable && enableGallery){
      try {
        await webdavClient?.mkdir('$webdavRemotePath/download');
        var cloudList = await webdavClient?.readDir('/JHentaiData/download');
        cloudList?.forEach((f) {
          print('${f.path}');
        });
        
        final directory = io.Directory(downloadSetting.downloadPath.value);
        var folders = directory.listSync().whereType<io.Directory>();
        for (var folder in folders) {
          log.info(folder.path);
          String gidStr = path.basename(folder.path).split(' - ')[0];
          int gid = int.tryParse(gidStr) ?? -1;
          if(gid == -1){
            continue;
          }
          if (!(cloudList?.any((file) => path.basename(file.path ?? '').startsWith(gidStr)) ?? false)) {
            await webdavUploadGallery(gid);
          }
        }

      } catch (e) {
        log.info('$e');
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
        log.info('导出到云端成功');
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
        log.info('从云端导入成功');
      } catch (e) {
        log.info('$e');
      }
    }
  }

  Future<void> webdavUploadGallery(int gid) async {
    if(enable && enableGallery){
      try {
        await webdavClient?.mkdir('$webdavRemotePath/download');
        log.info(downloadSetting.downloadPath.value);
        final directory = io.Directory(downloadSetting.downloadPath.value);
        var folders = directory.listSync().whereType<io.Directory>();
        for (var folder in folders) {
          if (path.basename(folder.path).startsWith('$gid - ')) {
            await _zipFolder(folder.path,'$gid');
            var zipFile=io.File('${downloadSetting.downloadPath.value}/$gid.zip');
            log.info('打包为 ${zipFile.path}');
            if(await zipFile.exists()){
              CancelToken c = CancelToken();
              await webdavClient?.writeFromFile(zipFile.path, '$webdavRemotePath/download/${path.basename(zipFile.path)}',onProgress: (c, t) {log.info(c / t);}, cancelToken: c);
            }
            else{
              log.info('${zipFile.path} 不存在');
            }
            await zipFile.delete();
            break;
          }
        }

        log.info('画廊 $gid 导出到云端成功');
      } catch (e) {
        log.info('$e');
      }
    }
  }



  Future<void> _zipFolder(String folderPath,String zipName) async {
    var zipFilePath = '${io.File(folderPath).parent.path}/$zipName.zip';
    if (await io.File(zipFilePath).exists()) {
      return;
    }
    final encoder = ZipFileEncoder();
    encoder.create(zipFilePath);
    encoder.addDirectory(io.Directory(folderPath));
    encoder.close();
    log.info('Folder zip successfully: $zipFilePath');
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
      _exportDataLoadingState = false;
    } on Exception catch (e) {
      log.error('Export data failed', e);
      log.info('internalError'.tr);
      _exportDataLoadingState = false;
      file.delete().ignore();
    }
  }
}