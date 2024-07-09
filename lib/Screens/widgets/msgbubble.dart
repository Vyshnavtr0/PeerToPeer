import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_chat_bubble/chat_bubble.dart';
import 'package:get_time_ago/get_time_ago.dart';

Padding MsgBubble(message, BuildContext context, int index,
    String formattedTime, dynamic widget) {
  return Padding(
    padding: const EdgeInsets.symmetric(
      vertical: 1,
      horizontal: 8,
    ),
    child: Column(
      crossAxisAlignment: message.sender == 'ME'
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        ChatBubble(
          shadowColor: Colors.transparent,
          clipper: ChatBubbleClipper5(
              type: message.sender == 'ME'
                  ? BubbleType.sendBubble
                  : BubbleType.receiverBubble),
          alignment:
              message.sender == 'ME' ? Alignment.topRight : Alignment.topLeft,
          margin: EdgeInsets.only(top: 0),
          backGroundColor: message.noprogress != 100
              ? Color(0xffE7EBF4)
              : message.isPhoto
                  ? Colors.transparent
                  : message.sender == 'ME'
                      ? Color(0xff315FF3)
                      : Color(0xffE7EBF4),
          child: Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.7,
            ),
            child: Column(
              crossAxisAlignment: message.sender == 'ME'
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(1.0),
                  child: message.isPhoto && message.noprogress == 100
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: Image.file(
                            File(message.message),
                            fit: BoxFit.cover,
                            height: MediaQuery.of(context).size.width / 2,
                            width: MediaQuery.of(context).size.width / 2,
                          ),
                        )
                      : message.noprogress != 100
                          ? Container(
                              height: 50,
                              child: Column(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        "🌆  ",
                                        style: TextStyle(
                                            fontSize: 30,
                                            color: message.sender == 'ME'
                                                ? Colors.white
                                                : Colors.black),
                                      ),
                                      Text(
                                        message.message,
                                        textAlign: TextAlign.right,
                                        style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: message.sender == 'ME'
                                                ? Colors.white
                                                : Colors.black),
                                      )
                                    ],
                                  ),
                                  SizedBox(
                                    height: 10,
                                  ),
                                  LinearProgressIndicator(
                                    value: message.noprogress / 100,
                                    backgroundColor: Colors.grey[200],
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white),
                                  ),
                                ],
                              ),
                            )
                          : Text(
                              message.message,
                              style: TextStyle(
                                  fontSize: 16,
                                  color: message.sender == 'ME'
                                      ? Colors.white
                                      : Colors.black),
                            ),
                ),
                Padding(
                  padding: const EdgeInsets.all(5.0),
                  child: Text(
                    index - 1 > 0
                        ? isTimeDifferenceGreaterThanoneday(
                                DateTime.parse(message.timestamp.toString()),
                                DateTime.parse(widget
                                    .view.messages[index - 1].timestamp
                                    .toString()))
                            ? formattedTime
                            : GetTimeAgo.parse(
                                DateTime.parse(message.timestamp.toString()))
                        : GetTimeAgo.parse(
                            DateTime.parse(message.timestamp.toString())),
                    style: TextStyle(
                        fontSize: 8,
                        color: message.sender == 'ME'
                            ? Colors.white
                            : Colors.black),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

bool isTimeDifferenceGreaterThanoneday(DateTime start, DateTime end) {
  const int minuteThreshold = 1440;
  Duration difference = end.difference(start);
  return difference.inMinutes > minuteThreshold;
}
