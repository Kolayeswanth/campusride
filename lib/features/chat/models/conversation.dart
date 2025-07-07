import 'package:flutter/material.dart';

class Conversation {
  final String id;
  final String title;
  final DateTime lastMessageTime;
  final int messageCount;
  final bool isUnread;
  final String lastMessagePreview;

  Conversation({
    required this.id,
    required this.title,
    required this.lastMessageTime,
    required this.messageCount,
    required this.isUnread,
    required this.lastMessagePreview,
  });

  factory Conversation.fromJson(Map<String, dynamic> json) {
    return Conversation(
      id: json['id'] as String,
      title: json['title'] as String,
      lastMessageTime: DateTime.parse(json['last_message_time'] as String),
      messageCount: json['message_count'] as int,
      isUnread: json['is_unread'] as bool,
      lastMessagePreview: json['last_message_preview'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'last_message_time': lastMessageTime.toIso8601String(),
      'message_count': messageCount,
      'is_unread': isUnread,
      'last_message_preview': lastMessagePreview,
    };
  }
} 