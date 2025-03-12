import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/extension/widget_extension.dart';
import 'package:jhentai/src/utils/toast_util.dart';

import '../../../../setting/network_setting.dart';

class SettingWebDAVPage extends StatefulWidget {
  const SettingWebDAVPage({Key? key}) : super(key: key);

  @override
  State<SettingWebDAVPage> createState() => _SettingWebDAVPageState();
}

class _SettingWebDAVPageState extends State<SettingWebDAVPage> {
  bool enableWebDAV = networkSetting.enableWebDAV.value;
  String? webdavURL = networkSetting.webdavURL.value;
  String? webdavPassword = networkSetting.webdavPassword.value;

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
              networkSetting.saveWebDAV(enableWebDAV, webdavURL, webdavPassword);
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
            _buildWebDAVPassword(),
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
        networkSetting.saveWebDAV(value,webdavURL,webdavPassword);
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
}
