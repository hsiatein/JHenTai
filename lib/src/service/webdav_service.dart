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
  Worker? _synchronizeListener;
  @override
  Future<void> doInitBean() async {
    Get.put(this, permanent: true);
    webdavClient=webdav_client.newClient(networkSetting.webdavURL.value ?? '', user: networkSetting.webdavUserName.value ?? '', password: networkSetting.webdavPassword.value ?? '');
    _synchronizeListener = everAll(
      [],
      (_) {
        synchronize();
      },
    );
  }

  @override
  Future<void> doAfterBeanReady() async {}

  @override
  void onClose() {
    super.onClose();

    _synchronizeListener?.dispose();
  }

  Future<void> synchronize() async {
    // 测试服务是否可以连接
    try {
      await webdavClient?.ping();
      log.info('success');
      log.info(webdavClient?.uri??'');
      log.info(webdavClient?.auth.user ?? '');
      log.info(webdavClient?.auth.pwd ?? '');
      var list = await webdavClient?.readDir('/');
      list?.forEach((f) {
        print('${f.name} ${f.path}');
      });
    } catch (e) {
      log.info('$e');
    }
  }
}