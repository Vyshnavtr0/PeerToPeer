import 'dart:convert';
import 'dart:io';
import 'package:chat_bubbles/bubbles/bubble_special_three.dart';
import 'package:chat_bubbles/chat_bubbles.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:emoji_selector/emoji_selector.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_chat_bubble/chat_bubble.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:get_time_ago/get_time_ago.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:mobx/mobx.dart';
import 'package:path_provider/path_provider.dart';
import 'package:peertopeer/Screens/pages/Splash.dart';
import 'package:peertopeer/Screens/widgets/msgbubble.dart';
import 'package:peertopeer/domain/encrpt.dart';
import 'package:peertopeer/core/webrtc_viewmodel.dart';
import 'package:permission_handler/permission_handler.dart';

class MyHomePage extends StatefulWidget {
  final dynamic view;
  MyHomePage({Key? key, required this.title, required this.view})
      : super(key: key);
  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final viewModel = WebRtcViewModel();
  final controller = TextEditingController();
  final msgController = TextEditingController();
  String key = 'mysecretkey';
  bool fileshow = false;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  Future<void> requestPermissions() async {
    var status = await Permission.storage.status;
    if (!status.isGranted) {
      await Permission.storage.request();
    }
  }

  @override
  void initState() {
    super.initState();
    requestPermissions();
    _loadImages();
  }

  final FocusNode _focusNode = FocusNode();
  bool emojishow = false;
  void _showEmojiKeyboard() {
    // Request focus on the text field to open the keyboard
    setState(() {
      emojishow = true;
    });
  }

  List<File> _images = [];
  Future<void> _loadImages() async {
    // Request storage permissions
    await Duration(seconds: 1);
    if (await Permission.storage.request().isGranted) {
      Directory? picturesDirectory = await getExternalStorageDirectory();
      if (picturesDirectory != null) {
        String picturesPath = picturesDirectory.path;
        Directory picturesDir = Directory(picturesPath);
        List<FileSystemEntity> files = picturesDir.listSync();

        List<File> images = files
            .where((file) {
              String path = file.path.toLowerCase();
              return path.endsWith('.jpg') ||
                  path.endsWith('.jpeg') ||
                  path.endsWith('.png');
            })
            .map((file) => File(file.path))
            .toList();

        setState(() {
          _images = images;
        });
      }
    } else {
      // Handle the case when permission is denied
      requestPermissions();
      print("Permission to access storage is denied");
    }
  }

  Future<RTCSessionDescription?> getSdpFromUser(BuildContext context) async {
    controller.clear();
    await showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              maxLines: 10,
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text("Done"),
            )
          ],
        ),
      ),
    );
    RTCSessionDescription? offer;
    try {
      final offerMap =
          json.decode(SimpleXOREncryption.decrypt(controller.text, key));
      offer = RTCSessionDescription(
        offerMap["sdp"],
        offerMap["type"],
      );
    } catch (e) {
      Fluttertoast.showToast(msg: "Make sure the format is correct");
    }
    return offer;
  }

  Future<void> _pickAndSendFile(bool c) async {
    try {
      final ImagePicker picker = ImagePicker();
// Pick an image.
      final XFile? image = await picker.pickImage(
          source: c ? ImageSource.camera : ImageSource.gallery);
      if (image != null) {
        Uint8List? fileData = await image.readAsBytes();
        String fileName = image.name;
        if (fileData != null) {
          await widget.view.sendFile(fileData, fileName, image.path);
        } else {
          Fluttertoast.showToast(msg: 'File data is null');
        }
      } else {
        Fluttertoast.showToast(msg: 'File picking cancelled');
      }
    } catch (e) {
      print('File picking error: $e');
      Fluttertoast.showToast(msg: 'Failed to pick file');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              child: Center(
                child: Text(
                  widget.title.toUpperCase().substring(0, 2),
                  style: TextStyle(color: Colors.black, fontSize: 15),
                ),
              ),
              decoration: BoxDecoration(
                  color: Color(0xffE7EBF4),
                  borderRadius: BorderRadius.circular(30)),
            ),
            SizedBox(
              width: 15,
            ),
            Text(
              widget.title,
              style: TextStyle(color: Colors.black),
            ),
          ],
        ),
        backgroundColor: Colors.white,
        elevation: 0.1,
        leading: IconButton(
          icon: Icon(
            CupertinoIcons.back,
            color: Colors.black,
          ),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Row(
            //   children: [
            //     Expanded(
            //       child: TextButton(
            //         child: Text("OFFER"),
            //         onPressed: () {
            //           widget.view.offerConnection();
            //         },
            //       ),
            //     ),
            //     Expanded(
            //       child: TextButton(
            //         child: Text("ANSWER"),
            //         onPressed: () async {
            //           final offer = await getSdpFromUser(context);
            //           if (offer == null) return;
            //           widget.view.answerConnection(offer);
            //         },
            //       ),
            //     ),
            //     Expanded(
            //       child: TextButton(
            //           child: Text("SET REMOTE"),
            //           onPressed: () async {
            //             final answer = await getSdpFromUser(context);
            //             if (answer == null) return;
            //             widget.view.acceptAnswer(answer);
            //           }),
            //     ),
            //   ],
            // ),
            Expanded(
              child: Observer(builder: (_) {
                print(_);
                return ListView.builder(
                  itemCount: widget.view.messages.length,
                  reverse: true,
                  shrinkWrap: true,
                  physics: BouncingScrollPhysics(),
                  itemBuilder: (context, index) {
                    dynamic message = widget.view.messages[index];
                    String formattedTime =
                        DateFormat.jm().format(message.timestamp);
                    return MsgBubble(
                        message, context, index, formattedTime, widget);
                  },
                );
              }),
            ),
            SizedBox(
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      margin: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                          color: Color(0xffE7EBF4),
                          borderRadius: BorderRadius.circular(12)),
                      child: Stack(
                        children: [
                          TextField(
                            controller: msgController,
                            maxLines: 3, focusNode: _focusNode,
                            minLines: 1,
                            onTap: () {
                              setState(() {
                                emojishow = false;
                                fileshow = false;
                              });
                            },
                            style: TextStyle(color: Colors.black),
                            onChanged: (t) {
                              setState(() {});
                            }, // Set text color
                            decoration: InputDecoration(
                                prefixIcon: IconButton(
                                  onPressed: () {},
                                  icon: Icon(
                                    CupertinoIcons.smiley,
                                    color: Colors.transparent,
                                    size: 20,
                                  ),
                                ),
                                suffixIcon: IconButton(
                                  onPressed: () {},
                                  icon: Icon(
                                    CupertinoIcons.camera,
                                    color: Colors.transparent,
                                    size: 20,
                                  ),
                                ),
                                focusColor: Colors.transparent,
                                contentPadding: EdgeInsets.symmetric(
                                    horizontal: 20, vertical: 15),
                                // Set label color
                                hintText: 'Type your message here',
                                hintStyle: TextStyle(
                                    color: Colors.black54, fontSize: 14),
                                border: InputBorder.none),
                          ),
                          Positioned(
                            left:
                                0.0, // Adjust as needed for horizontal alignment
                            bottom: 0.0,
                            child: Align(
                              alignment: Alignment.bottomLeft,
                              child: IconButton(
                                onPressed: () {
                                  fileshow = fileshow;
                                  if (emojishow) {
                                    setState(() {
                                      emojishow = false;
                                      fileshow = false;
                                      FocusScope.of(context)
                                          .requestFocus(_focusNode);
                                    });
                                  } else {
                                    _showEmojiKeyboard();
                                    FocusScope.of(context).unfocus();
                                  }
                                },
                                icon: Icon(
                                  emojishow
                                      ? CupertinoIcons.keyboard
                                      : CupertinoIcons.smiley,
                                  color: Colors.black,
                                  size: 20,
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Align(
                              alignment: Alignment.bottomRight,
                              child:
                                  msgController.text.trimLeft().trimRight() !=
                                          ''
                                      ? IconButton(
                                          onPressed: () {
                                            msgController.clear();
                                            setState(() {});
                                          },
                                          icon: Icon(
                                            CupertinoIcons.clear,
                                            color: Colors.black,
                                            size: 20,
                                          ),
                                        )
                                      : IconButton(
                                          onPressed: () {
                                            _pickAndSendFile(true);
                                          },
                                          icon: Icon(
                                            CupertinoIcons.camera,
                                            color: Colors.black,
                                            size: 20,
                                          ),
                                        ),
                            ),
                          )
                        ],
                      ),
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                        color: Color(0xff315FF3),
                        borderRadius: BorderRadius.circular(12)),
                    margin: EdgeInsets.all(8),
                    child: msgController.text != ""
                        ? IconButton(
                            icon: Icon(
                              CupertinoIcons.paperplane,
                              color: Colors.white,
                            ),
                            onPressed: () async {
                              if (msgController.text.isNotEmpty) {
                                await widget.view.sendMessage(
                                    msgController.text.trimLeft().trimLeft());
                                msgController.clear();
                                setState(() {});
                              }
                            },
                          )
                        : IconButton(
                            icon: Icon(
                              fileshow
                                  ? CupertinoIcons.clear
                                  : CupertinoIcons.add,
                              color: Colors.white,
                            ),
                            onPressed: () {
                              if (!fileshow) {
                                FocusScope.of(context).unfocus();
                              } else {
                                FocusScope.of(context).requestFocus(_focusNode);
                              }
                              setState(() {
                                fileshow = !fileshow;
                                emojishow = false;
                              });
                            },
                          ),
                  ),
                ],
              ),
            ),
            EmojiWidget(),
            FileWidget()
          ],
        ),
      ),
    );
  }

  AnimatedContainer FileWidget() {
    return AnimatedContainer(
      height: fileshow ? 300 : 0,
      duration: Duration(milliseconds: 200),
      child: Column(
        children: [
          SizedBox(
            height: 200,
            child: _images.isNotEmpty
                ? GridView.builder(
                    padding: const EdgeInsets.all(8.0),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 8.0,
                      mainAxisSpacing: 8.0,
                    ),
                    itemCount: _images.length,
                    itemBuilder: (context, index) {
                      return Image.file(
                        _images[index],
                        fit: BoxFit.cover,
                      );
                    },
                  )
                : Center(
                    child: TextButton(
                        onPressed: () {
                          _loadImages();
                        },
                        child: Text(
                          "No images found",
                          style: TextStyle(fontSize: 16, color: Colors.black),
                        )),
                  ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Column(
                children: [
                  Container(
                    decoration: BoxDecoration(
                        color: Color(0xffE7EBF4),
                        borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(3.0),
                      child: IconButton(
                        onPressed: () {
                          _pickAndSendFile(false);
                        },
                        iconSize: 30,
                        icon: Icon(CupertinoIcons.photo),
                      ),
                    ),
                  ),
                  SizedBox(
                    height: 10,
                  ),
                  Text(
                    "Gallery",
                    style: TextStyle(fontSize: 12, color: Colors.black),
                  )
                ],
              ),
              Column(
                children: [
                  Container(
                    decoration: BoxDecoration(
                        color: Color(0xffE7EBF4),
                        borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(3.0),
                      child: IconButton(
                        onPressed: () {},
                        iconSize: 30,
                        icon: Icon(CupertinoIcons.paperclip),
                      ),
                    ),
                  ),
                  SizedBox(
                    height: 10,
                  ),
                  Text(
                    "File",
                    style: TextStyle(fontSize: 12, color: Colors.black),
                  )
                ],
              ),
              Column(
                children: [
                  Container(
                    decoration: BoxDecoration(
                        color: Color(0xffE7EBF4),
                        borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(3.0),
                      child: IconButton(
                        onPressed: () {},
                        iconSize: 30,
                        icon: Icon(CupertinoIcons.person),
                      ),
                    ),
                  ),
                  SizedBox(
                    height: 10,
                  ),
                  Text(
                    "Contact",
                    style: TextStyle(fontSize: 12, color: Colors.black),
                  )
                ],
              ),
              Column(
                children: [
                  Container(
                    decoration: BoxDecoration(
                        color: Color(0xffE7EBF4),
                        borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(3.0),
                      child: IconButton(
                        onPressed: () {},
                        iconSize: 30,
                        icon: Icon(CupertinoIcons.location),
                      ),
                    ),
                  ),
                  SizedBox(
                    height: 10,
                  ),
                  Text(
                    "Location",
                    style: TextStyle(fontSize: 12, color: Colors.black),
                  )
                ],
              )
            ],
          )
        ],
      ),
    );
  }

  AnimatedContainer EmojiWidget() {
    return AnimatedContainer(
      height: emojishow ? 330 : 0,
      duration: Duration(milliseconds: 200),
      child: EmojiSelector(
        padding: EdgeInsets.all(8),
        columns: 7,
        rows: 3,
        withTitle: true,
        onSelected: (emoji) {
          print('Selected emoji ${emoji.char}');
          setState(() {
            msgController.text = msgController.text + emoji.char;
          });
        },
      ),
    );
  }
}

extension ObservableListExtensions<T> on ObservableList<T> {
  T elementAtReversed(int index) {
    return this[length - index - 1];
  }
}
