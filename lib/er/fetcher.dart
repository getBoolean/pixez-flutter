/*
 * Copyright (C) 2020. by perol_notsf, All rights reserved
 *
 * This program is free software: you can redistribute it and/or modify it under
 * the terms of the GNU General Public License as published by the Free Software
 * Foundation, either version 3 of the License, or (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful, but WITHOUT ANY
 *  WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
 *  FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License along with
 *  this program. If not, see <http://www.gnu.org/licenses/>.
 */

import 'dart:io';

import 'dart:isolate';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pixez/component/pixiv_image.dart';
import 'package:pixez/er/lprinter.dart';
import 'package:pixez/er/toaster.dart';
import 'package:pixez/i18n.dart';
import 'package:pixez/main.dart';
import 'package:pixez/models/illust.dart';
import 'package:pixez/models/task_persist.dart';
import 'package:pixez/store/save_store.dart';
import 'package:quiver/collection.dart';

class PixivClientAdapter implements HttpClientAdapter {
  final HttpClientAdapter _adapter = HttpClientAdapter();

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final uri = options.uri;
    // Hook requests to pub.dev
    if (uri.host == 'pub.dev') {
      return ResponseBody.fromString('Welcome to pub.dev', 200);
    }
    return _adapter.fetch(options, requestStream, cancelFuture);
  }

  @override
  void close({bool force = false}) {
    _adapter.close(force: force);
  }
}

enum IsoTaskState { INIT, APPEND, PROGRESS, ERROR, COMPLETE }

class IsoContactBean {
  final IsoTaskState state;
  final dynamic data;

  IsoContactBean({required this.state, required this.data});
}

class IsoProgressBean {
  final int min, total;
  final String url;

  IsoProgressBean({required this.min, required this.total, required this.url});
}

class TaskBean {
  String? url;
  Illusts? illusts;
  String? fileName;
  String? savePath;
  String? source;
  String? host;
  bool? byPass;

  TaskBean(
      {required this.url,
      required this.illusts,
      required this.fileName,
      required this.savePath,
      this.byPass,
      this.host,
      this.source});
}

class Fetcher {
  BuildContext? context;
  List<TaskBean> queue = [];
  ReceivePort receivePort = ReceivePort();
  SendPort? sendPortToChild;
  Isolate? isolate;
  TaskPersistProvider taskPersistProvider = TaskPersistProvider();
  LruMap<String, JobEntity> jobMaps = LruMap();

  Fetcher() {}

  start() async {
    if (receivePort.isBroadcast) return;
    await taskPersistProvider.open();
    await taskPersistProvider.getAllAccount();
    LPrinter.d("Fetcher start");
    receivePort.listen((message) {
      try {
        IsoContactBean isoContactBean = message;
        switch (isoContactBean.state) {
          case IsoTaskState.INIT:
            sendPortToChild = isoContactBean.data;
            break;
          case IsoTaskState.PROGRESS:
            IsoProgressBean isoProgressBean = isoContactBean.data;
            var job = fetcher.jobMaps[isoProgressBean.url];
            if (job != null) {
              job
                ..min = isoProgressBean.min
                ..status = 1
                ..max = isoProgressBean.total;
            } else {
              fetcher.jobMaps[isoProgressBean.url] = JobEntity()
                ..status = 1
                ..min = isoProgressBean.min
                ..max = isoProgressBean.total;
            }
            break;
          case IsoTaskState.COMPLETE:
            TaskBean taskBean = isoContactBean.data;
            urlPool.remove(taskBean.url);
            if (queue.isNotEmpty) {
              queue.removeWhere((element) => element.url == taskBean.url);
              LPrinter.d("c ${queue.length}");
            }
            fetcher.jobMaps.removeWhere((key, value) => key == taskBean.url);
            nextJob();
            _complete(taskBean.url!, taskBean.savePath!, taskBean.fileName!,
                taskBean.illusts!);
            break;
          case IsoTaskState.ERROR:
            TaskBean taskBean = isoContactBean.data;
            urlPool.remove(taskBean.url);
            if (queue.isNotEmpty) {
              queue.removeWhere((element) => element.url == taskBean.url);
              LPrinter.d("c ${queue.length}");
            }
            fetcher.jobMaps.removeWhere((key, value) => key == taskBean.url);
            nextJob();
            _errorD(taskBean.url!);
            break;
          default:
            break;
        }
      } catch (e) {}
    });
    isolate = await Isolate.spawn(entryPoint, receivePort.sendPort,
        debugName: 'childIsolate');
  }

  save(String url, Illusts illusts, String fileName) async {
    LPrinter.d(sendPortToChild.toString() + url);
    var taskBean = TaskBean(
        url: url,
        illusts: illusts,
        fileName: fileName,
        byPass: userSetting.disableBypassSni,
        source: userSetting.pictureSource,
        host: splashStore.host,
        savePath: (await getTemporaryDirectory()).path);
    queue.add(taskBean);
    nextJob();
  }

  List<String> urlPool = [];

  nextJob() {
    if (queue.isNotEmpty && urlPool.length < userSetting.maxRunningTask) {
      TaskBean? first = null;
      for (var i in queue) {
        if (!urlPool.contains(i.url)) {
          first = i;
          break;
        }
      }
      if (first == null) return;
      first.byPass = userSetting.disableBypassSni;
      first.source = userSetting.pictureSource;
      first.host = splashStore.host;
      IsoContactBean isoContactBean =
          IsoContactBean(state: IsoTaskState.APPEND, data: first);
      sendPortToChild?.send(isoContactBean);
      if (first.url != null) urlPool.add(first.url!);
    }
  }

  void stop() {
    isolate?.kill(priority: Isolate.immediate);
  }

  Future<void> _complete(
    String url,
    String savePath,
    String fileName,
    Illusts illusts,
  ) async {
    var taskPersist = await taskPersistProvider.getAccount(url);
    if (taskPersist == null) return;
    await taskPersistProvider.update(taskPersist..status = 2);
    File file = File(savePath + Platform.pathSeparator + fileName);
    final uint8list = await file.readAsBytes();
    await saveStore.saveToGallery(uint8list, illusts, fileName);
    Toaster.downloadOk("${illusts.title} ${I18n.of(context!).saved}");
    var job = jobMaps[url];
    if (job != null) {
      job.status = 2;
    } else {
      jobMaps[url] = JobEntity()
        ..status = 2
        ..min = 1
        ..max = 1;
    }
  }

  Future<void> _errorD(String url) async {
    var taskPersist = await taskPersistProvider.getAccount(url);
    if (taskPersist == null) return;
    await taskPersistProvider.update(taskPersist..status = 3);
    var job = jobMaps[url];
    if (job != null) {
      job.status = 3;
    } else {
      jobMaps[url] = JobEntity()
        ..status = 3
        ..min = 1
        ..max = 1;
    }
  }
}

class Seed {}

Dio isolateDio = Dio(BaseOptions(headers: {
  "referer": "https://app-api.pixiv.net/",
  "User-Agent": "PixivIOSApp/5.8.0",
  "Host": "i.pximg.net"
}));
// 新Isolate入口函数
entryPoint(SendPort sendPort) {
  LPrinter.d("entryPoint =======");
  String inHost = splashStore.host;
  String inSource = userSetting.pictureSource!;
  bool inBypass = userSetting.disableBypassSni;
  if (!userSetting.disableBypassSni) {
    isolateDio.httpClientAdapter = IOHttpClientAdapter()
      ..createHttpClient = () {
        final httpclient = HttpClient();
        httpclient.badCertificateCallback = (cert, host, port) => true;
        return httpclient;
      };
  }
  ReceivePort receivePort = ReceivePort();
  sendPort.send(
      IsoContactBean(state: IsoTaskState.INIT, data: receivePort.sendPort));
  receivePort.listen((message) async {
    try {
      IsoContactBean isoContactBean = message;
      TaskBean taskBean = isoContactBean.data;
      switch (isoContactBean.state) {
        case IsoTaskState.ERROR:
          break;
        case IsoTaskState.APPEND:
          try {
            inHost = taskBean.host!;
            inSource = taskBean.source!;
            inBypass = taskBean.byPass!;
            LPrinter.d(
                "append ======= host:${inHost} source:${inSource} bypass:${inBypass}");
            var savePath = taskBean.savePath! +
                Platform.pathSeparator +
                taskBean.fileName!;
            String trueUrl = '';
            final isContainPathSource = inSource.contains('/');
            if (isContainPathSource) {
              trueUrl = 'https://${inHost}${Uri.parse(taskBean.url!).path}';
            } else {
              trueUrl = taskBean.byPass == true
                  ? taskBean.url!
                  : (Uri.parse(taskBean.url!).replace(
                          host: inSource == ImageHost || inSource == ImageSHost
                              ? inHost
                              : inSource))
                      .toString();
            }
            LPrinter.d(
                "append ======= host:${inHost} source:${inSource} bypass:${inBypass} ${trueUrl}");
            if (!isContainPathSource) {
              isolateDio.options.headers['Host'] = taskBean.source == ImageHost
                  ? Uri.parse(taskBean.url!).host
                  : taskBean.source;
            } else {
              isolateDio.options.headers['Host'] = inHost.split('/').first;
            }
            isolateDio.download(trueUrl, savePath,
                onReceiveProgress: (min, total) {
              sendPort.send(IsoContactBean(
                  state: IsoTaskState.PROGRESS,
                  data: IsoProgressBean(
                      min: min, total: total, url: taskBean.url!)));
            }).then((value) {
              sendPort.send(
                  IsoContactBean(state: IsoTaskState.COMPLETE, data: taskBean));
            }).catchError((e) {
              try {
                splashStore.maybeFetch();
                sendPort.send(
                    IsoContactBean(state: IsoTaskState.ERROR, data: taskBean));
              } catch (e) {
                LPrinter.d(e);
              }
            });
          } catch (e) {
            LPrinter.d("fetcher=======");
            LPrinter.d(e);
            sendPort.send(
                IsoContactBean(state: IsoTaskState.ERROR, data: taskBean));
          }
          break;
        default:
          break;
      }
    } catch (e) {
      LPrinter.d(e);
    }
  });
}
