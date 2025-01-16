import 'package:another_flushbar/flushbar.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

class SettingController extends GetxController {
  final box = GetStorage('fileSync');

  final serverAddress = "".obs;
  final fileExtension = "".obs;

  @override
  Future<void> onInit() async {
    serverAddress.value = box.read('server_address') ?? 'https://';
    fileExtension.value = box.read("file_extension") ?? '.mp3';
    print("onInit server address: ${serverAddress.value}");
    print("onInit file extension: ${fileExtension.value}");
    super.onInit();
    _initialized = true;
  }

  bool _initialized = false;
  Future<void> ensureInitialization() async {
    while (!_initialized) {
      await onInit();
    }
    return;
  }

  setServerAddress(String address) {
    serverAddress.value = address;
    box.write('server_address', address);
  }

  setFileExtension(String extension) {
    fileExtension.value = extension;
    box.write("file_extension", extension);
  }

  String getServerAddress() {
    return serverAddress.value;
  }

  String getFileExtension() {
    return fileExtension.value;
  }
}

class SettingPage extends StatelessWidget {
  const SettingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("设置")),
      body: const _Setting(),
    );
  }
}

class _Setting extends StatefulWidget {
  const _Setting();

  @override
  State<_Setting> createState() => __SettingState();
}

class __SettingState extends State<_Setting> {
  final settingController = Get.find<SettingController>();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(10.0),
      child: Column(
        children: [
          const Text('服务器地址：'),
          TextField(
            controller: TextEditingController(
                text: settingController.getServerAddress()),
            onChanged: (value) {
              // serviceAddress = value;
              print("set server address: $value");
              settingController.setServerAddress(value);
            },
          ),
          Divider(),
          const Text('文件后缀：'),
          TextField(
            controller: TextEditingController(
                text: settingController.getFileExtension()),
            onChanged: (value) {
              // fileExtension = value;
              settingController.setFileExtension(value);
            },
          ),
        ],
      ),
    );
  }
}

// ignore: constant_identifier_names
enum FlushLevel { OK, INFO, WARNING }

void flushBar(FlushLevel level, String? title, String? message,
    {bool upperPosition = false}) {
  Color? color;
  IconData? icon;
  switch (level) {
    case FlushLevel.OK:
      color = Colors.green.shade300;
      icon = Icons.check_box_sharp;
      break;
    case FlushLevel.INFO:
      color = Colors.blue.shade300;
      icon = Icons.info_outline;
      break;
    case FlushLevel.WARNING:
      color = Colors.orange.shade300;
      icon = Icons.error_outline;
      break;
  }
  Flushbar(
    title: title,
    message: message,
    titleSize: 30,
    messageSize: 24,
    duration: const Duration(seconds: 3),
    icon: Icon(icon, size: 28, color: color),
    margin: const EdgeInsets.all(12.0),
    borderRadius: BorderRadius.circular(8.0),
    leftBarIndicatorColor: color,
    flushbarPosition:
        upperPosition ? FlushbarPosition.TOP : FlushbarPosition.BOTTOM,
  ).show(Get.context!);
}
