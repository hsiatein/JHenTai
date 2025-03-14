import 'dart:async';
import 'dart:core';
import 'dart:io' as io;
import 'package:dio/dio.dart';

import 'package:get/get_core/src/get_main.dart';
import 'package:get/get_instance/src/extension_instance.dart';
import 'package:get/get_rx/get_rx.dart';
import 'package:get/get_state_manager/src/simple/get_controllers.dart';
import 'package:get/get_utils/get_utils.dart';
import 'package:jhentai/src/database/database.dart';

import 'package:jhentai/src/setting/network_setting.dart';

import 'package:jhentai/src/service/log.dart';
import 'package:jhentai/src/utils/toast_util.dart';

import 'package:jhentai/src/enum/config_type_enum.dart';
import 'package:jhentai/src/service/cloud_service.dart';

import 'package:jhentai/src/model/config.dart';
import 'package:jhentai/src/service/isolate_service.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

import 'jh_service.dart';
import 'package:webdav_client/webdav_client.dart' as webdav_client;
import 'package:jhentai/src/setting/download_setting.dart';
import 'package:path/path.dart' as path;
import 'package:archive/archive_io.dart';
import 'dart:convert';
import 'package:jhentai/src/service/gallery_download_service.dart';
import 'package:jhentai/src/service/path_service.dart';
import 'package:http_parser/http_parser.dart';
import 'dart:typed_data';

/// Responsible for local images meta-data and download all images of a gallery
WebDAVService webdavService = WebDAVService();

class WebDAVService extends GetxController with JHLifeCircleBeanErrorCatch implements JHLifeCircleBean {
  webdav_client.Client? webdavClient;
  bool _exportDataLoadingState = false;
  bool _importDataLoadingState = false;
  String webdavCachePath='';
  String webdavCacheJsonPath='';
  final String webdavRemotePath='/JHentaiData';
  bool enable=false;
  bool enableGallery=false;
  

  @override
  Future<void> doInitBean() async {
    enable=networkSetting.enableWebDAV.value;
    enableGallery=networkSetting.enableWebDAVSynchronizeGallery.value;
    if(enable){
      Get.put(this, permanent: true);
      webdavClient=webdav_client.newClient(networkSetting.webdavURL.value ?? '', user: networkSetting.webdavUserName.value ?? '', password: networkSetting.webdavPassword.value ?? '');
      final directory =pathService.getVisibleDir();
      log.info(directory.path);
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
        log.info('ping 成功');
      } catch (e) {
        log.info('$e');
      }
    }
  }

  Future<void> webdavInitProcess() async {
    try{
      log.info('清除缓存');
      io.Directory cache=io.Directory(webdavCachePath);
      if(await cache.exists()){
        Iterable<io.File> files= cache.listSync().whereType<io.File>();
        for(var file in files){
          await file.delete();
        }
      }
      else{
        _createCache();
      }
      log.info('清除远程错误文件');
      webdavClient?.mkdirAll('/JHentaiData/download');
      var cloudList = await webdavClient?.readDir('/JHentaiData/download');
      for(var file in cloudList!){
        if(file.path?.endsWith('.zip') ?? true){
          continue;
        }
        await webdavClient?.remove(file.path!);
      }
    }catch(e){
      log.error("$e");
    }
    try{
      await webdavDownloadData();
    }catch(e){
      log.error("$e");
    }
    try{
      await webdavDownloadAllGalleries();
    }catch(e){
      log.error("$e");
    }
    try{
      await webdavUploadAllGalleries();
    }catch(e){
      log.error("$e");
    }
  }

  Future<void> webdavDownloadAllGalleries() async {
    if(enable && enableGallery){
      try {
        await webdavClient?.mkdir('$webdavRemotePath/download');
        var cloudList = await webdavClient?.readDir('/JHentaiData/download');
        if(cloudList==null){
          return;
        }
        final directory = io.Directory(downloadSetting.downloadPath.value);
        var folders = directory.listSync().whereType<io.Directory>();
        for (var zipFileCloud in cloudList) {
          try{
            log.info('检查是否需要下载'+(path.basename(zipFileCloud.path??'')));
            String gidStr = path.basename(zipFileCloud.path??'').split('.zip')[0];
            int gid = int.tryParse(gidStr) ?? -1;
            if(gid == -1){
              continue;
            }
            //log.info('查找 $gid');
            bool needDownload=true;
            for(var folder in folders){
              if(path.basename(folder.path).startsWith(gidStr)){
                String metadataPath=path.join(folder.path,'metadata');
                io.File metadataFile=io.File(metadataPath);
                if(!(await metadataFile.exists())){
                  folder.delete();
                  break;
                }
                String metadata=await metadataFile.readAsString();
                Map<String, dynamic> metadataMap = jsonDecode(metadata);
                if (metadataMap["gallery"]['downloadStatusIndex'] != 4) {
                  log.info('${path.basename(folder.path)} 未下载完成');
                  Iterable<io.File> files= folder.listSync().whereType<io.File>();
                  for(var file in files){
                    await file.delete();
                  }
                  await folder.delete();
                }
                else{
                  needDownload=false;
                }
                break;
              }
            }
            if(needDownload){
              await webdavDownloadGallery(gid);
            }
          }catch (e) {
            log.error('$e');
            continue;
          }
        }

      } catch (e) {
        log.error('$e');
      }
    }
  }

  Future<void> webdavDownloadGallery(int gid)async{
    try{
      log.info('下载 $gid 到 $webdavCachePath/$gid.zip');
      String remotePath="$webdavRemotePath/download/$gid.zip";
      String zipPath='$webdavCachePath/$gid.zip';
      await webdavClient?.read2File(remotePath, zipPath);
      await _cleanFile(zipPath);
      await extractFileToDisk(zipPath, downloadSetting.downloadPath.value);
      //io.File(zipPath).delete();
      galleryDownloadService.restoreTasks();
      log.info('下载 $gid 成功');
    }catch(e){
      log.error('$e');
    }
  }

  Future<void> webdavUploadAllGalleries() async {
    if(enable && enableGallery){
      try {
        await webdavClient?.mkdir('$webdavRemotePath/download');
        var cloudList = await webdavClient?.readDir('/JHentaiData/download');
        
        final directory = io.Directory(downloadSetting.downloadPath.value);
        var folders = directory.listSync().whereType<io.Directory>();
        for (var folder in folders) {
          try{
            log.info(folder.path);
            String gidStr = path.basename(folder.path).split(' - ')[0];
            int gid = int.tryParse(gidStr) ?? -1;
            if(gid == -1){
              continue;
            }
            if (cloudList?.any((file) => path.basename(file.path ?? '').startsWith(gidStr)) ?? false) {
              log.info('${path.basename(folder.path)} 已经存在');
              continue;
            }
            String metadataPath=path.join(folder.path,'metadata');
            io.File metadataFile=io.File(metadataPath);
            String metadata=await metadataFile.readAsString();
            Map<String, dynamic> metadataMap = jsonDecode(metadata);
            if (metadataMap["gallery"]['downloadStatusIndex'] != 4) {
              log.info('${path.basename(folder.path)} 未下载完成');
              continue;
            }
            log.info('开始上传 ${path.basename(folder.path)}');
            await webdavUploadGallery(gid);
          }catch (e) {
            log.error('$e');
            continue;
          }
        }

      } catch (e) {
        log.error('$e');
      }
    }
  }



  Future<void> webdavUploadData() async {
    if(enable){
      try {
        await webdavClient?.mkdir(webdavRemotePath);
        await _exportData();
        if(await io.File(webdavCacheJsonPath).exists()){
          
          await _uploadFile(webdavCacheJsonPath, '$webdavRemotePath/${CloudConfigService.configFileName}-WebDAV.json');
          await io.File(webdavCacheJsonPath).delete();
        }
        log.info('导出到云端成功');
      } catch (e) {
        log.error('$e');
      }
    }
  }
  Future<void> webdavDownloadData() async {
    if(enable){
      try {
        await _createCache();
        await webdavClient?.read2File('$webdavRemotePath/${CloudConfigService.configFileName}-WebDAV.json', webdavCacheJsonPath);
        //io.File(webdavCacheJsonPath+'.zip').delete();
        if (await io.File(webdavCacheJsonPath).exists()) {
          await _importData();
        }
        //io.File(webdavCacheJsonPath).delete();
        log.info('从云端导入成功');
      } catch (e) {
        log.error('$e');
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
          if (!(path.basename(folder.path).startsWith('$gid - '))) {
            continue;
          }
          await _zipFolder(folder.path,'$gid');
          var zipFile=io.File('$webdavCachePath/$gid.zip');
          log.info('打包为 ${zipFile.path}');
          if(await zipFile.exists()){
            await _uploadFile(zipFile.path, '$webdavRemotePath/download/${path.basename(zipFile.path)}');
          }
          else{
            log.error('${zipFile.path} 不存在');
          }
          //await zipFile.delete();
          break;
        }

        log.info('画廊 $gid 导出到云端成功');
      } catch (e) {
        log.error('$e');
      }
    }
  }

  Future<void> _cleanFile(String filePath) async {
    final file = io.File(filePath);
    final bytes = await file.readAsBytes();

    // 定义需要查找的字节序列
    final List<int> targetStart = [0x50, 0x4b]; // ZIP 文件开头
    final List<int> boundarySequence = [
      0x0d, 0x0a, 0x0d, 0x0a, 0x50, 0x4b
    ]; // 边界序列

    final List<int> endSequence = [
      0x0d, 0x0a, 0x2d, 0x2d, 0x2d, 0x2d
    ]; // 结束序列

    // 检查文件开头
    if (bytes[0] == targetStart[0] && bytes[1] == targetStart[1]) {
      return; // 文件以 50 4b 开头，不做处理
    } else if (bytes[0] == 0x2d) {
      // 文件以 2d 开头，进行处理
      // 查找边界序列
      final startIndex = _findSequenceIndex(bytes,boundarySequence)+4;
      // 创建新的字节数组，从边界序列开始
      final cleanedBytes = bytes.sublist(startIndex);
      // 从后往前查找结束序列
      final endIndex = _findSequenceIndex(cleanedBytes,endSequence,fromEnd: true);

      // 创建最终的字节数组，去掉结束序列之前的内容
      final finalBytes = cleanedBytes.sublist(0, endIndex).toList();

      // 写回文件
      await file.writeAsBytes(finalBytes);
    } 
  }

  Future<void> _uploadFile(String filePath, String remotePath) async {
    String? url=webdavClient?.uri;
    if(url==null){
      return;
    }
    if(url.endsWith('/')){
      url=url.substring(0,url.length-1);
    }
    url=url+remotePath;
    String username=webdavClient?.auth.user ?? '';
    String password=webdavClient?.auth.pwd ?? '';
    Dio dio = Dio();
    // 设置基本认证
    String basicAuth = 'Basic ${base64Encode(utf8.encode('$username:$password'))}';
    dio.options.headers['Authorization'] = basicAuth;
    try {
      // 创建 FormData
      String fileName = io.File(filePath).uri.pathSegments.last; // 获取文件名
      MediaType mediaType;
      if(fileName.endsWith('.zip')){
        mediaType=MediaType('application', 'zip');
      }
      else{
        mediaType=MediaType('application', 'json');
      }
      FormData formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(filePath, filename: fileName,contentType: mediaType), // 使用获取的文件名
      });
      // 发送 PUT 请求
      Response response = await dio.put(url, data: formData);
      // 检查响应状态
      if (response.statusCode == 200 || response.statusCode == 201) {
        log.info('文件上传成功！');
      } else {
        log.error('上传失败: ${response.statusCode} - ${response.data}');
      }
    } catch (e) {
      log.error('发生错误: $e');
    }
  }


  Future<void> _zipFolder(String folderPath,String zipName) async {
    var zipFilePath = '$webdavCachePath/$zipName.zip';
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
      int startIndex=0;
      int endIndex=string.length;
      for(int i=0;i<string.length;i++){
        if(string[i]=='['){
          startIndex=i;
          break;
        }
      }
      for(int i=string.length-1;i>=0;i--){
        if(string[i]==']'){
          endIndex=i+1;
          break;
        }
      }
      string=string.substring(startIndex,endIndex);
      List list = await isolateService.jsonDecodeAsync(string);
      List<CloudConfig> configs = list.map((e) => CloudConfig.fromJson(e)).toList();
      for (CloudConfig config in configs) {
        await cloudConfigService.importConfig(config);
      }
      _importDataLoadingState = false;
    } catch (e, s) {
      log.error('Import data failed', e, s);
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
      _exportDataLoadingState = false;
      file.delete().ignore();
    }
  }

  int _findSequenceIndex(Uint8List bytes, List<int> sequence, {bool fromEnd = false}) {
    final sequenceLength = sequence.length;
    for (int i = (fromEnd ? bytes.length - sequenceLength : 0);
        fromEnd ? i >= 0 : i <= bytes.length - sequenceLength;
        fromEnd ? i-- : i++) {
      if (_listEqual(bytes.sublist(i, i + sequenceLength).toList(),sequence)) {
        return i;
      }
    }
    return -1;
  }

  bool _listEqual(List<int> a,List<int> b){
    if (a.length != b.length){
      return false;
    }
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]){
        return false;
      }
    }
    return true;
  }

}