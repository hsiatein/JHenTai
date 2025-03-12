import 'dart:io' as io;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/config/ui_config.dart';
import 'package:jhentai/src/extension/string_extension.dart';
import 'package:jhentai/src/extension/widget_extension.dart';
import 'package:jhentai/src/service/local_gallery_service.dart';
import 'package:jhentai/src/setting/download_setting.dart';
import 'package:jhentai/src/setting/user_setting.dart';
import 'package:jhentai/src/utils/file_util.dart';
import 'package:jhentai/src/utils/toast_util.dart';
import 'package:jhentai/src/widget/eh_wheel_speed_controller.dart';
import 'package:jhentai/src/widget/loading_state_indicator.dart';
import 'package:path/path.dart';

import '../../../routes/routes.dart';
import '../../../service/archive_download_service.dart';
import '../../../service/gallery_download_service.dart';
import '../../../service/log.dart';
import '../../../utils/permission_util.dart';
import '../../../utils/route_util.dart';
import '../../../widget/eh_download_dialog.dart';

class SettingWebDAVPage extends StatefulWidget {
  const SettingWebDAVPage({Key? key}) : super(key: key);

  @override
  State<SettingWebDAVPage> createState() => _SettingWebDAVPageState();
}

class _SettingWebDAVPageState extends State<SettingWebDAVPage> {
  LoadingState changeDownloadPathState = LoadingState.idle;

  final ScrollController scrollController = ScrollController();

  @override
  void dispose() {
    super.dispose();
    scrollController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(centerTitle: true, title: Text('webdavSetting'.tr)),
      body: Obx(
        () => EHWheelSpeedController(
          controller: scrollController,
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.only(top: 16),
            children: [
              _buildWebDAVConnectionURL()
            ],
          ).withListTileTheme(context),
        ),
      ),
    );
  }

  Widget _buildWebDAVConnectionURL() {
    return ListTile(
      title: Text('WebDAVConnectionURL'.tr),
      trailing: changeDownloadPathState == LoadingState.loading ? const CupertinoActivityIndicator() : null,
      onTap: () {

      },
    );
  }
}