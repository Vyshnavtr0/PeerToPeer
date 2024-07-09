import 'dart:io';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:mobx/mobx.dart';
import 'package:equatable/equatable.dart';
import 'dart:convert';

import 'package:path_provider/path_provider.dart';
import 'package:peertopeer/domain/appdata.dart';
import 'package:peertopeer/domain/encrpt.dart';
import 'package:permission_handler/permission_handler.dart';
part 'webrtc_viewmodel.g.dart';

Map<String, dynamic> _connectionConfiguration = {
  'iceServers': [
    {'url': 'stun:stun.l.google.com:19302'},
  ]
};

const _offerAnswerConstraints = {
  'mandatory': {
    'OfferToReceiveAudio': false,
    'OfferToReceiveVideo': false,
  },
  'optional': [],
};

class WebRtcViewModel = _WebRtcViewModelBase with _$WebRtcViewModel;

abstract class _WebRtcViewModelBase with Store {
  late RTCDataChannel _dataChannel;
  late RTCPeerConnection _connection;
  late RTCSessionDescription _sdp;
  List<Uint8List> _receivedFileChunks = <Uint8List>[];
  int _receivedChunksCount = 0;
  int _totalChunks = 0;
  String _receivedFileName = '';
  String key = 'mysecretkey';
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  @observable
  ObservableList<Message> messages = ObservableList.of([]);
  List<String> chopTextIntoThreePieces(String text) {
    List<String> pieces = [];
    if (text.length >= 3) {
      int segmentLength = (text.length / 3).ceil();
      pieces.add(text.substring(0, segmentLength));
      pieces.add(text.substring(segmentLength, segmentLength * 2));
      pieces.add(text.substring(segmentLength * 2));
    } else {
      // Handle case where text is too short to chop into three pieces
      pieces.add(text); // Add entire text as one piece
      pieces.add(''); // Add empty string for second piece
      pieces.add(''); // Add empty string for third piece
    }
    return pieces;
  }

  DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
  Future<String> getdid() async {
    AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
    return androidInfo.device;
  }

  Future<void> addData(String t) async {
    try {
      // Split the text 't' into three pieces
      List<String> pieces = await chopTextIntoThreePieces(t);

      // Add data to Firestore

      String d = await getdid();
      await _firestore.collection('users').doc(d).set({
        'sdp1': pieces.length > 0 ? pieces[0] : '',
        'sdp2': pieces.length > 1 ? pieces[1] : '',
        'sdp3': pieces.length > 2 ? pieces[2] : '',
      });

      print('Data added successfully');
    } catch (e) {
      print('Error adding data: $e');
    }
  }

  @action
  Future<void> offerConnection() async {
    _connection = await _createPeerConnection();
    await _createDataChannel();
    RTCSessionDescription offer =
        await _connection.createOffer(_offerAnswerConstraints);
    await _connection.setLocalDescription(offer);
    _sdpChanged();
    //messages.add(Message.fromSystem("Created offer"));
  }

  @action
  Future<void> answerConnection(RTCSessionDescription offer) async {
    _connection = await _createPeerConnection();
    await _connection.setRemoteDescription(offer);
    final answer = await _connection.createAnswer(_offerAnswerConstraints);
    await _connection.setLocalDescription(answer);
    _sdpChanged();
    // messages.add(Message.fromSystem("Created Answer"));
  }

  @action
  Future<void> acceptAnswer(RTCSessionDescription answer) async {
    await _connection.setRemoteDescription(answer);
    //messages.add(Message.fromSystem("Answer Accepted"));
  }

  @action
  Future<void> sendMessage(String message) async {
    await _dataChannel.send(RTCDataChannelMessage(message));
    messages.insert(
        0,
        Message.fromUser("ME", message, false,
            isPhoto: false,
            isVideo: false,
            timestamp: DateTime.timestamp(),
            noprogress: 100,
            noprogressTotalChunks: 100));
  }

  @action
  Future<void> sendFile(
      Uint8List fileData, String fileName, String path) async {
    // Chunk size for sending data
    const chunkSize = 16384; // 16 KB
    print(path);
    // Calculate number of chunks
    int totalChunks = (fileData.length / chunkSize).ceil();

    // Send metadata first (e.g., filename and total number of chunks)
    await _dataChannel.send(RTCDataChannelMessage(
        "file_meta:${json.encode({'name': fileName, 'chunks': totalChunks})}"));

    // Send file data in chunks
    for (int i = 0; i < totalChunks; i++) {
      int start = i * chunkSize;
      int end = (i + 1) * chunkSize;
      if (end > fileData.length) {
        end = fileData.length;
      }
      Uint8List chunk = Uint8List.sublistView(fileData, start, end);
      await _dataChannel.send(RTCDataChannelMessage.fromBinary(chunk));
    }
    messages.insert(
        0,
        Message.fromUser('ME', "${path}", false,
            isPhoto: true,
            isVideo: false,
            timestamp: DateTime.timestamp(),
            noprogress: 100,
            noprogressTotalChunks: 100));
  }

  Future<RTCPeerConnection> _createPeerConnection() async {
    final con = await createPeerConnection(_connectionConfiguration);
    con.onIceCandidate = (candidate) {
      //messages.add(Message.fromSystem("New ICE candidate"));
      _sdpChanged();
    };
    con.onDataChannel = (channel) {
      //messages.add(Message.fromSystem("Received data channel"));
      _addDataChannel(channel);
    };
    return con;
  }

  void _sdpChanged() async {
    _sdp = (await _connection.getLocalDescription())!;
    final text = await SimpleXOREncryption.encrypt(
        (json.encode(_sdp.toMap())).toString(), key);
    addData(text);
    print("Data added");
    AppData.updateVariable(text);
    Clipboard.setData(ClipboardData(text: text));
  }

  Future<void> _createDataChannel() async {
    RTCDataChannelInit dataChannelDict = new RTCDataChannelInit();
    RTCDataChannel channel =
        await _connection.createDataChannel("textchat-chan", dataChannelDict);
    //messages.add(Message.fromSystem("Created data channel"));
    _addDataChannel(channel);
  }

  void _addDataChannel(RTCDataChannel channel) {
    _dataChannel = channel;

    _dataChannel.onMessage = (RTCDataChannelMessage data) {
      if (data.isBinary) {
        // messages.add(Message.fromSystem("Received binary data", false));
        _handleReceivedFile(data.binary);
      } else if (data.text.startsWith("file_meta:")) {
        String metaJson = data.text.substring(10);
        Map<String, dynamic> meta = json.decode(metaJson);
        messages.insert(
            0,
            Message.fromUser('OTHER', _receivedFileName, false,
                timestamp: DateTime.timestamp(),
                isPhoto: true,
                isVideo: false,
                noprogressTotalChunks: 100,
                noprogress: 0));
        //messages.add(Message.fromSystem("Received file metadata: $meta"));
        _prepareToReceiveFile(meta['name'], meta['chunks']);
      } else {
        //messages.add(Message.fromSystem("Received text data: ${data.text}"));
        messages.insert(
            0,
            Message.fromUser("OTHER", data.text, false,
                isPhoto: false,
                isVideo: false,
                noprogress: 100,
                timestamp: DateTime.timestamp(),
                noprogressTotalChunks: 100));
      }
    };

    _dataChannel.onDataChannelState = (RTCDataChannelState state) {
      //messages.add(Message.fromSystem("Data channel state: $state"));
      if (state == RTCDataChannelState.RTCDataChannelOpen) {
        //messages.add(Message.fromSystem("Data channel is open"));
      } else if (state == RTCDataChannelState.RTCDataChannelClosed) {
        //messages.add(Message.fromSystem("Data channel is closed"));
      }
    };
  }

  Future<String> saveFileToDownloads(
      Uint8List fileData, String fileName) async {
    Directory downloadsDirectory =
        await getApplicationDocumentsDirectory(); // change to getExternalStorageDirectory() if you want to save to external storage
    String filePath = '${downloadsDirectory.path}/$fileName';
    File file = File(filePath);
    ImageGallerySaver.saveImage(fileData);
    await file.writeAsBytes(fileData);
    print(downloadsDirectory.path);
    return filePath;
  }

  void _handleReceivedFile(Uint8List fileData) {
    if (fileData.isNotEmpty) {
      // Check if the incoming data is metadata or a file chunk
      try {
        String dataStr = utf8.decode(fileData);
        if (dataStr.startsWith("file_meta:")) {
          String metaJson = dataStr.substring(10);
          Map<String, dynamic> meta = json.decode(metaJson);

          _prepareToReceiveFile(meta['name'], meta['chunks']);
        } else {
          _addFileChunk(fileData);
        }
      } catch (e) {
        // If utf8 decoding fails, assume it's a binary chunk
        _addFileChunk(fileData);
      }
    } else {
      //messages.add(Message.fromSystem("Received empty file data"));
    }
  }

  void _addFileChunk(Uint8List chunk) {
    _receivedFileChunks.add(chunk);
    _receivedChunksCount++;

    // messages.add(Message.fromSystem(
    //     "Received chunk $_receivedChunksCount of $_totalChunks"));
    messages.removeAt(0);
    messages.insert(
        0,
        Message.fromUser('OTHER', _receivedFileName, false,
            timestamp: DateTime.timestamp(),
            isPhoto: true,
            isVideo: false,
            noprogressTotalChunks: 100,
            noprogress: (_receivedChunksCount / _totalChunks) * 100));

    if (_receivedChunksCount == _totalChunks) {
      //messages.add(Message.fromSystem("All chunks received"));
      _saveReceivedFile();
    }
  }

  void _prepareToReceiveFile(String fileName, int totalChunks) {
    _receivedFileChunks = [];
    _receivedChunksCount = 0;
    _totalChunks = totalChunks;
    _receivedFileName = fileName;
  }

  Future<void> _saveReceivedFile() async {
    try {
      Uint8List completeFileData = Uint8List(0);
      for (var chunk in _receivedFileChunks) {
        completeFileData = Uint8List.fromList([...completeFileData, ...chunk]);
      }

      String result =
          await saveFileToDownloads(completeFileData, _receivedFileName);
      print(result);
      messages.removeAt(0);
      messages.insert(
          0,
          Message.fromUser('OTHER', result, false,
              timestamp: DateTime.timestamp(),
              isPhoto: true,
              isVideo: false,
              noprogressTotalChunks: 100,
              noprogress: 100));

      // messages.add(Message.fromSystem("File saved to: "));
    } catch (e) {
      //messages.add(Message.fromSystem("Error saving file: $e"));
    } finally {
      _resetFileReception();
    }
  }

  void _resetFileReception() {
    _receivedFileChunks = [];
    _receivedChunksCount = 0;
    _totalChunks = 0;
    _receivedFileName = '';
  }
}

@immutable
class Message extends Equatable {
  final String sender;
  final bool isSystem;
  final bool isfile;
  String message;
  final DateTime timestamp;
  final bool isVideo;
  final bool isPhoto;
  double noprogress;
  int noprogressTotalChunks;

  Message(this.sender, this.isSystem, this.message, this.isfile,
      {required this.timestamp,
      required this.isVideo,
      required this.isPhoto,
      required this.noprogress,
      required this.noprogressTotalChunks});

  Message.fromUser(this.sender, this.message, this.isfile,
      {required this.timestamp,
      required this.isVideo,
      required this.isPhoto,
      required this.noprogressTotalChunks,
      required this.noprogress})
      : isSystem = false;
  Message copyWithUpdatedPath(String newPath) {
    return Message(
      this.sender,
      this.isSystem,
      newPath,
      this.isfile,
      timestamp: this.timestamp,
      isVideo: this.isVideo,
      isPhoto: this.isPhoto,
      noprogressTotalChunks: this.noprogressTotalChunks,
      noprogress: 100,
    );
  }

  @override
  List<Object> get props => [
        sender,
        isSystem,
        message,
        isfile,
        timestamp,
        isVideo,
        isPhoto,
        noprogressTotalChunks,
      ];
}
