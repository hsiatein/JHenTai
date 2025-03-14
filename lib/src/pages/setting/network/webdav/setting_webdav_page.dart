import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/extension/widget_extension.dart';
import 'package:jhentai/src/service/storage_service.dart';
import 'package:jhentai/src/utils/toast_util.dart';
import 'package:jhentai/src/service/webdav_service.dart';
import 'package:jhentai/src/service/log.dart';

import '../../../../setting/network_setting.dart';

class SettingWebDAVPage extends StatefulWidget {
  const SettingWebDAVPage({Key? key}) : super(key: key);

  @override
  State<SettingWebDAVPage> createState() => _SettingWebDAVPageState();
}

class _SettingWebDAVPageState extends State<SettingWebDAVPage> {
  bool enableWebDAV = networkSetting.enableWebDAV.value;
  String? webdavURL = networkSetting.webdavURL.value;
  String? webdavUserName = networkSetting.webdavUserName.value;
  String? webdavPassword = networkSetting.webdavPassword.value;
  bool enableWebDAVSynchronizeGallery = networkSetting.enableWebDAVSynchronizeGallery.value;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text('webdavSetting'.tr),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: () {
              networkSetting.saveWebDAV(enableWebDAV, webdavURL, webdavUserName, webdavPassword,enableWebDAVSynchronizeGallery);
              toast('success'.tr);
            },
          ),
        ],
      ),
      body: Obx(
        () => ListView(
          padding: const EdgeInsets.only(top: 16),
          children: [
            _buildEnableWebDAV(),
            _buildWebDAVURL(),
            _buildWebDAVUserName(),
            _buildWebDAVPassword(),
            _buildEnableWebDAVSynchronizeGallery(),
            _buildSynchronizeNow(),
          ],
        ),
      ).withListTileTheme(context),
    );
  }

  Widget _buildEnableWebDAV() {
    return SwitchListTile(
      title: Text('enableWebDAV'.tr),
      value: networkSetting.enableWebDAV.value,
      onChanged: (value) {
        enableWebDAV=value;
        networkSetting.saveWebDAV(value, webdavURL, webdavUserName, webdavPassword,enableWebDAVSynchronizeGallery);
      },
    );
  }


  Widget _buildWebDAVURL() {
    return ListTile(
      title: Text('webdavURL'.tr),
      trailing: SizedBox(
        width: 150,
        child: TextField(
          controller: TextEditingController(text: networkSetting.webdavURL.value),
          decoration: const InputDecoration(isDense: true, labelStyle: TextStyle(fontSize: 12)),
          textAlign: TextAlign.center,
          onChanged: (String value) => webdavURL = value,
        ),
      ),
    );
  }

  Widget _buildWebDAVUserName() {
    return ListTile(
      title: Text('webdavUserName'.tr),
      trailing: SizedBox(
        width: 150,
        child: TextField(
          controller: TextEditingController(text: networkSetting.webdavUserName.value),
          decoration: const InputDecoration(isDense: true, labelStyle: TextStyle(fontSize: 12)),
          textAlign: TextAlign.center,
          onChanged: (String value) => webdavUserName = value,
        ),
      ),
    );
  }

  Widget _buildWebDAVPassword() {
    return ListTile(
      title: Text('webdavPassword'.tr),
      trailing: SizedBox(
        width: 150,
        child: TextField(
          controller: TextEditingController(text: networkSetting.webdavPassword.value),
          decoration: const InputDecoration(isDense: true, labelStyle: TextStyle(fontSize: 12)),
          textAlign: TextAlign.center,
          onChanged: (String value) => webdavPassword = value,
        ),
      ),
    );
  }

  Widget _buildSynchronizeNow() {
    return ListTile(
      title: Text('synchronizeNow'.tr),
      onTap: () {
        //webdavService.testSynchronize();
        //log.info('测试同步');
        //webdavService.webdavUploadAllGalleries();
        webdavService.webdavDownloadAllGalleries();
      },
    );
  }

  Widget _buildEnableWebDAVSynchronizeGallery() {
    return SwitchListTile(
      title: Text('enableWebDAVSynchronizeGallery'.tr),
      value: networkSetting.enableWebDAVSynchronizeGallery.value,
      onChanged: (value) {
        enableWebDAVSynchronizeGallery=value;
        networkSetting.saveWebDAV(value, webdavURL, webdavUserName, webdavPassword,enableWebDAVSynchronizeGallery);
      },
    );
  }
}
