import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:custom_qr_generator/custom_qr_generator.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:mobx/mobx.dart';
import 'package:peertopeer/Screens/pages/Chat.dart';
import 'package:peertopeer/domain/appdata.dart';
import 'package:peertopeer/domain/encrpt.dart';
import 'package:peertopeer/main.dart';
import 'package:peertopeer/core/webrtc_viewmodel.dart';
import 'package:qr_bar_code_scanner_dialog/qr_bar_code_scanner_dialog.dart';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  final viewModel = WebRtcViewModel();
  final _qrBarCodeScannerDialogPlugin = QrBarCodeScannerDialog();
  DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
  String key = 'mysecretkey';
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

  Future<String> getdid() async {
    AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
    setState(() {
      AppData.id = androidInfo.device;
    });
    return androidInfo.device;
  }

  void _showBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Container(
          padding: EdgeInsets.all(16.0),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Center(
                child: AppData.id != ''
                    ? CustomPaint(
                        painter: QrPainter(
                            data: AppData.id,
                            options: const QrOptions(
                                shapes: QrShapes(
                                    darkPixel: QrPixelShapeRoundCorners(
                                        cornerFraction: .5),
                                    frame: QrFrameShapeRoundCorners(
                                        cornerFraction: .25),
                                    ball: QrBallShapeRoundCorners(
                                        cornerFraction: .25)),
                                colors: QrColors(
                                    dark: QrColorLinearGradient(
                                        colors: [
                                      Colors.black,
                                      Colors.grey,
                                    ],
                                        orientation: GradientOrientation
                                            .leftDiagonal)))),
                        size: const Size(250, 250),
                      )
                    : Text(''),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  OutlinedButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    child: Text('Close'),
                    style: OutlinedButton.styleFrom(
                      primary: Colors.black, // Text color
                      side: BorderSide(color: Colors.black), // Border color
                      padding:
                          EdgeInsets.symmetric(horizontal: 50, vertical: 12),
                      textStyle: TextStyle(fontSize: 16),
                    ),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      primary: Colors.black, // Button background color
                      onPrimary: Colors.white, // Button text color
                      padding:
                          EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      textStyle: TextStyle(fontSize: 16),
                    ),
                    onPressed: () {
                      String t = '';

                      // Use await here to wait for the barcode scanning to complete
                      _qrBarCodeScannerDialogPlugin.getScannedQrBarCode(
                        context: context,
                        onCode: (code) async {
                          setState(() {
                            t = code!;
                          });
                          final f = await fetchDataAndMerge(t);
                          final o = await getSdpFromUser(context, f);

                          if (o == null) return;
                          await viewModel.answerConnection(o);
                          Future.delayed(Duration(seconds: 3), () async {
                            await addData(AppData.sdp, t);
                          });

                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => MyHomePage(
                                      title: t,
                                      view: viewModel,
                                    )), // Navigate to NextScreen
                          );
                        },
                      );
                    },
                    child: Text('Scan QR code'),
                  ),
                ],
              )
            ],
          ),
        );
      },
    );
  }

  Future<List<Map<String, String>>> fetchData() async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection('users')
          .doc(AppData.id)
          .collection('offer')
          .get();
      List<Map<String, String>> mergedData = [];

      for (QueryDocumentSnapshot doc in snapshot.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        String merged = '${data['sdp1']}${data['sdp2']}${data['sdp3']}';
        mergedData.add({'id': doc.id, 'mergedData': merged});
      }

      return mergedData;
    } catch (e) {
      print('Error fetching data: $e');
      return [];
    }
  }

  Future<void> addData(String t, String di) async {
    try {
      // Split the text 't' into three pieces
      List<String> pieces = chopTextIntoThreePieces(t);

      // Add data to Firestore

      String d = await getdid();
      await _firestore
          .collection('users')
          .doc(di)
          .collection("offer")
          .doc(d)
          .set({
        'sdp1': pieces.length > 0 ? pieces[0] : '',
        'sdp2': pieces.length > 1 ? pieces[1] : '',
        'sdp3': pieces.length > 2 ? pieces[2] : '',
      });

      print('Data added successfully');
    } catch (e) {
      print('Error adding data: $e');
    }
  }

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  Future<String> fetchDataAndMerge(String t) async {
    try {
      print(t);
      DocumentSnapshot documentSnapshot = await _firestore
          .collection('users')
          .doc(t.replaceFirst('http://', '').toString())
          .get();
      if (documentSnapshot.exists) {
        Map<String, dynamic> data =
            documentSnapshot.data() as Map<String, dynamic>;
        String merged = '${data['sdp1']}${data['sdp2']}${data['sdp3']}';
        Fluttertoast.showToast(msg: merged);
        return merged;
      } else {
        Fluttertoast.showToast(msg: 'jj');
        return 'Document does not exist';
      }
    } catch (e) {
      Fluttertoast.showToast(msg: 'tt$t');
      print('Error fetching data: $e');
      return 'Error fetching data';
    }
  }

  Future<RTCSessionDescription?> getSdpFromUser(
      BuildContext context, String t) async {
    RTCSessionDescription? offer;
    try {
      final offerMap = json.decode(SimpleXOREncryption.decrypt(t, key));
      offer = RTCSessionDescription(
        offerMap["sdp"],
        offerMap["type"],
      );
    } catch (e) {
      Fluttertoast.showToast(msg: "Make sure the format is correct");
    }
    return offer;
  }

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    viewModel.offerConnection();
    getdid();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _showBottomSheet(context);
        },
        elevation: 8,
        splashColor: Colors.white,
        backgroundColor: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
              color: Color(0xffE7EBF4),
              borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(13.0),
            child: Icon(
              Icons.edit_outlined,
              color: Colors.black,
            ),
          ),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            height: 60,
          ),
          FutureBuilder<List<Map<String, String>>>(
            future: fetchData(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(child: CircularProgressIndicator());
              } else if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return Center(child: Text('No data found'));
              } else {
                return ListView.builder(
                  itemCount: snapshot.data!.length,
                  shrinkWrap: true,
                  itemBuilder: (context, index) {
                    final document = snapshot.data![index];
                    return Visibility(
                      visible: document['sdp1'] == '' ? false : true,
                      child: ListTile(
                        title: Text(
                          document['id']!,
                          style: TextStyle(fontSize: 20),
                        ),
                        trailing: Icon(
                          Icons.arrow_right_outlined,
                          size: 30,
                        ),
                        onTap: () async {
                          print(document['mergedData']);

                          final o = await getSdpFromUser(
                              context, document['mergedData']!);

                          if (o == null) return;
                          viewModel.acceptAnswer(o);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => MyHomePage(
                                      title: document['id']!,
                                      view: viewModel,
                                    )), // Navigate to NextScreen
                          );
                        },
                      ),
                    );
                  },
                );
              }
            },
          ),
          TextButton(
              onPressed: () {
                setState(() {
                  fetchData();
                });
              },
              child: Text("Refresh"))
        ],
      ),
    );
  }
}
