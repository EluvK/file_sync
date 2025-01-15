import 'dart:io';
import 'dart:convert';
import 'package:file_sync/setting.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:crypto/crypto.dart';

void main() async {
  await Get.putAsync(() async {
    final controller = SettingController();
    return controller;
  });

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    var app = GetMaterialApp(
      initialRoute: '/',
      getPages: [
        GetPage(name: '/', page: () => const FileExplorerScreen()),
        GetPage(name: '/setting', page: () => const SettingPage()),
      ],
    );
    return app;
  }
}

class FileExplorerScreen extends StatefulWidget {
  const FileExplorerScreen({super.key});

  @override
  FileExplorerScreenState createState() => FileExplorerScreenState();
}

class FileExplorerScreenState extends State<FileExplorerScreen> {
  List<FileSystemEntity> _files = [];
  late final settingController = Get.find<SettingController>();
  bool _isTFCardAvailable = true; // 标记TF卡是否可用
  bool _isSyncing = false; // 标记是否正在同步
  String directoryString = '';

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  // 检查权限
  Future<void> _checkPermissions() async {
    if (await Permission.storage.request().isGranted) {
      _loadFiles();
    } else {
      // 如果没有权限，显示权限请求
      await Permission.storage.request();
    }
  }

  // 加载TF卡目录下的文件
  Future<void> _loadFiles() async {
    try {
      final Directory dir = await _getDirectory();
      final List<FileSystemEntity> files = dir.listSync();
      setState(() {
        _files = files;
        _isTFCardAvailable = true; // TF卡可用
      });
    } catch (e) {
      setState(() {
        _isTFCardAvailable = false; // TF卡不可用
      });
      print("Error loading files: $e");
    }
  }

  // 获取目录，Windows平台使用临时目录调试，Android设备使用外部存储目录
  Future<Directory> _getDirectory() async {
    if (Platform.isWindows) {
      // 在Windows平台上使用临时目录进行调试
      final directory = Directory("D:\\TEST");
      if (!await directory.exists()) {
        throw Exception("目录不存在");
      }
      return directory;
    } else {
      // 获取外部存储目录路径，在Android设备上，这通常是类似于 "/storage/emulated/0"
      final directory = await getExternalStorageDirectory();
      if (directory == null || !await directory.exists()) {
        throw Exception("无法获取外部存储目录或目录不存在");
      }
      directoryString = directory.path;
      return directory;
    }
  }

  // 计算文件的MD5哈希值
  Future<String> _calculateFileHash(File file) async {
    final bytes = await file.readAsBytes();
    final digest = md5.convert(bytes);
    return digest.toString();
  }

  // 从服务端获取文件元数据
  Future<List<Metadata>> _fetchMetadata() async {
    String baseUrl = settingController.getServerAddress();
    HttpClient client = HttpClient();
    client.badCertificateCallback =
        ((X509Certificate cert, String host, int port) => true);
    HttpClientRequest request =
        await client.getUrl(Uri.parse('$baseUrl/metadata'));
    HttpClientResponse response = await request.close();
    if (response.statusCode == 200) {
      String responseBody = await response.transform(utf8.decoder).join();
      final List<dynamic> data = jsonDecode(responseBody);
      return data.map((item) => Metadata.fromResp(item)).toList();
    } else {
      throw Exception('Failed to load metadata');
    }
  }

  // 下载文件
  Future<void> _downloadFile(String fileName, Directory dir) async {
    String baseUrl = settingController.getServerAddress();
    HttpClient client = HttpClient();
    client.badCertificateCallback =
        ((X509Certificate cert, String host, int port) => true);
    HttpClientRequest request =
        await client.getUrl(Uri.parse('$baseUrl/download/$fileName'));
    HttpClientResponse response = await request.close();
    if (response.statusCode == 200) {
      final file = File('${dir.path}/$fileName');
      await file
          .writeAsBytes(await response.expand((element) => element).toList());
    } else {
      throw Exception('Failed to download file: $fileName');
    }
  }

  // 同步文件
  Future<void> _syncFiles() async {
    setState(() {
      _isSyncing = true;
    });
    var cnt = 0;

    try {
      final dir = await _getDirectory();
      final remoteMetadata = await _fetchMetadata();

      for (final metadata in remoteMetadata) {
        final fileName = metadata.name;
        final remoteHash = metadata.hash;
        final localFile = File('${dir.path}/$fileName');

        if (await localFile.exists()) {
          // 如果本地文件存在，比较哈希值
          final localHash = await _calculateFileHash(localFile);
          if (localHash == remoteHash) {
            print('File $fileName is up to date');
            continue;
          }
        }

        // 下载文件
        print('Downloading file: $fileName');
        await _downloadFile(fileName, dir);
        cnt++;
      }

      flushBar(FlushLevel.OK, '同步完成', '同步完成: $cnt 个文件');
    } catch (e) {
      flushBar(FlushLevel.WARNING, '同步失败', '同步失败: $e');
    } finally {
      setState(() {
        _isSyncing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('TF卡文件更新'),
        actions: [
          IconButton(
              onPressed: () {
                Get.toNamed('/setting');
              },
              icon: const Icon(Icons.settings))
        ],
      ),
      body: Column(
        children: [
          // 文件列表或提示信息
          Text(directoryString),
          Expanded(
            child: _isTFCardAvailable
                ? ListView.builder(
                    itemCount: _files.length,
                    itemBuilder: (context, index) {
                      final file = _files[index];
                      return ListTile(
                        title: Text(file.path.split('/').last),
                        onTap: () {
                          // 点击文件时打开文件或进行相应操作
                          print('Clicked: ${file.path}');
                        },
                      );
                    },
                  )
                : const Center(
                    child: Text(
                      "未检测到TF卡，请插入TF卡后刷新",
                      style: TextStyle(fontSize: 18, color: Colors.red),
                    ),
                  ),
          ),

          // 按钮区域
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: _isSyncing
                      ? null
                      : () async {
                          await _syncFiles();
                        },
                  child: _isSyncing
                      ? const CircularProgressIndicator()
                      : const Text("下载", style: TextStyle(fontSize: 24)),
                ),
                ElevatedButton(
                  onPressed: () {
                    _loadFiles();
                  },
                  child: const Text("刷新", style: TextStyle(fontSize: 24)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class Metadata {
  String name;
  String hash;

  Metadata({required this.name, required this.hash});

  factory Metadata.fromResp(Map<String, dynamic> map) {
    return Metadata(
      name: map["name"],
      hash: map["hash"],
    );
  }
}
