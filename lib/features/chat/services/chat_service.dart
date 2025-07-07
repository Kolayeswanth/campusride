import 'package:flutter/material.dart';
import '../models/conversation.dart';

class ChatService extends ChangeNotifier {
  List<Conversation> _conversations = [];
  bool _isLoading = false;
  String? _error;

  List<Conversation> get conversations => _conversations;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadConversations() async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      // TODO: Replace with actual API call
      // Simulated data for now
      await Future.delayed(const Duration(seconds: 1));
      _conversations = [
        Conversation(
          id: '1',
          title: 'Bus Route #123',
          lastMessageTime: DateTime.now().subtract(const Duration(minutes: 5)),
          messageCount: 3,
          isUnread: true,
          lastMessagePreview: 'The bus will arrive in 5 minutes',
        ),
        Conversation(
          id: '2',
          title: 'Driver Support',
          lastMessageTime: DateTime.now().subtract(const Duration(hours: 1)),
          messageCount: 2,
          isUnread: false,
          lastMessagePreview: 'Thank you for your feedback',
        ),
        Conversation(
          id: '3',
          title: 'Route Updates',
          lastMessageTime: DateTime.now().subtract(const Duration(hours: 2)),
          messageCount: 1,
          isUnread: false,
          lastMessagePreview: 'New route schedule available',
        ),
      ];

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to load conversations';
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> createNewChat() async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      // TODO: Replace with actual API call
      await Future.delayed(const Duration(seconds: 1));
      
      final newConversation = Conversation(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: 'New Chat',
        lastMessageTime: DateTime.now(),
        messageCount: 0,
        isUnread: false,
        lastMessagePreview: '',
      );

      _conversations.insert(0, newConversation);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to create new chat';
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> markAsRead(String conversationId) async {
    try {
      final index = _conversations.indexWhere((c) => c.id == conversationId);
      if (index != -1) {
        final conversation = _conversations[index];
        _conversations[index] = Conversation(
          id: conversation.id,
          title: conversation.title,
          lastMessageTime: conversation.lastMessageTime,
          messageCount: conversation.messageCount,
          isUnread: false,
          lastMessagePreview: conversation.lastMessagePreview,
        );
        notifyListeners();
      }
    } catch (e) {
      _error = 'Failed to mark conversation as read';
      notifyListeners();
    }
  }
} 