import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../models/message_filter_model.dart';
import '../../models/message_model.dart';
import '../../navigation/app_routes.dart';
import '../../services/native_main_phone_service.dart';
import '../../widgets/common/app_bottom_nav_bar.dart';
import '../../widgets/messages/message_filter_bar.dart';
import '../../widgets/messages/message_list.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen>
    with WidgetsBindingObserver {
  final NativeMainPhoneService nativeService = const NativeMainPhoneService();

  StreamSubscription<void>? messageUpdatesSubscription;
  Timer? refreshTimer;

  MessageFilter selectedFilter = MessageFilter.all;

  bool isSearchOpen = false;
  bool isLoading = true;
  bool isRefreshing = false;

  String searchQuery = '';

  List<MessageModel> messages = [];

  List<MessageModel> get filteredMessages {
    List<MessageModel> result = List.from(messages);

    switch (selectedFilter) {
      case MessageFilter.sms:
        result = result.where((m) => m.type == MessageType.sms).toList();
        break;
      case MessageFilter.push:
        result = result.where((m) => m.type == MessageType.push).toList();
        break;
      case MessageFilter.errors:
        result = result.where((m) => m.status == MessageStatus.error).toList();
        break;
      case MessageFilter.all:
        break;
    }

    final query = searchQuery.toLowerCase().trim();

    if (query.isNotEmpty) {
      result = result.where((m) {
        return m.sender.toLowerCase().contains(query) ||
            m.text.toLowerCase().contains(query) ||
            m.deviceName.toLowerCase().contains(query);
      }).toList();
    }

    return result;
  }

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    _loadMessages();
    _listenMessageUpdates();
    _startAutoRefresh();
  }

  @override
  void dispose() {
    messageUpdatesSubscription?.cancel();
    refreshTimer?.cancel();

    WidgetsBinding.instance.removeObserver(this);

    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadMessages();
      _listenMessageUpdates();
      _startAutoRefresh();
      return;
    }

    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      messageUpdatesSubscription?.cancel();
      messageUpdatesSubscription = null;

      refreshTimer?.cancel();
      refreshTimer = null;
    }
  }

  void _listenMessageUpdates() {
    messageUpdatesSubscription?.cancel();

    messageUpdatesSubscription = nativeService.messageUpdates.listen((_) {
      _loadMessages();
    });
  }

  void _startAutoRefresh() {
    refreshTimer?.cancel();

    refreshTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _loadMessages(showLoader: false);
    });
  }

  Future<void> _loadMessages({bool showLoader = true}) async {
    if (isRefreshing) {
      return;
    }

    isRefreshing = true;

    final nativeMessages = await nativeService.getMessages();

    if (!mounted) {
      isRefreshing = false;
      return;
    }

    final newMessages = nativeMessages.map(_mapNativeMessage).toList();

    setState(() {
      messages = newMessages;

      if (showLoader || isLoading) {
        isLoading = false;
      }
    });

    isRefreshing = false;
  }

  MessageModel _mapNativeMessage(NativeForwardedMessage message) {
    final date = DateTime.fromMillisecondsSinceEpoch(message.receivedAt);

    return MessageModel(
      sender: message.displayTitle,
      text: message.displaySubtitle,
      deviceName: message.deviceName.isEmpty
          ? 'Главный телефон'
          : message.deviceName,
      time: _formatTime(date),
      type: message.isSms ? MessageType.sms : MessageType.push,
      status: _mapStatus(message.status),
      date: date,
    );
  }

  MessageStatus _mapStatus(String status) {
    switch (status.toLowerCase().trim()) {
      case 'sent':
        return MessageStatus.sent;
      case 'error':
        return MessageStatus.error;
      case 'received':
      default:
        return MessageStatus.received;
    }
  }

  String _formatTime(DateTime date) {
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');

    return '$hour:$minute';
  }

  void toggleSearch() {
    setState(() {
      isSearchOpen = !isSearchOpen;

      if (!isSearchOpen) {
        searchQuery = '';
      }
    });
  }

  Future<void> _clearMessages() async {
    await nativeService.clearMessages();
    await _loadMessages();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _Header(
              isSearchOpen: isSearchOpen,
              searchQuery: searchQuery,
              hasMessages: messages.isNotEmpty,
              onSearchTap: toggleSearch,
              onClearTap: _clearMessages,
              onSearchChanged: (value) {
                setState(() {
                  searchQuery = value;
                });
              },
            ),
            MessageFilterBar(
              selectedFilter: selectedFilter,
              onChanged: (filter) {
                setState(() {
                  selectedFilter = filter;
                });
              },
            ),
            Expanded(
              child: isLoading
                  ? const Center(
                child: CircularProgressIndicator(
                  color: AppColors.primary,
                ),
              )
                  : MessageList(messages: filteredMessages),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const AppBottomNavBar(
        currentRoute: AppRoutes.messages,
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final bool isSearchOpen;
  final bool hasMessages;
  final String searchQuery;
  final VoidCallback onSearchTap;
  final VoidCallback onClearTap;
  final ValueChanged<String> onSearchChanged;

  const _Header({
    required this.isSearchOpen,
    required this.hasMessages,
    required this.searchQuery,
    required this.onSearchTap,
    required this.onClearTap,
    required this.onSearchChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (isSearchOpen) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 8),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                autofocus: true,
                controller: TextEditingController(text: searchQuery)
                  ..selection = TextSelection.collapsed(
                    offset: searchQuery.length,
                  ),
                onChanged: onSearchChanged,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Поиск сообщений...',
                  hintStyle: const TextStyle(color: AppColors.textSecondary),
                  filled: true,
                  fillColor: AppColors.card,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: const BorderSide(color: AppColors.cardBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: const BorderSide(color: AppColors.cardBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: const BorderSide(color: AppColors.primary),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            GestureDetector(
              onTap: onSearchTap,
              child: const Icon(
                Icons.close,
                color: AppColors.primary,
                size: 28,
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 8),
      child: Row(
        children: [
          const Icon(
            Icons.message_outlined,
            color: AppColors.primary,
            size: 32,
          ),
          const SizedBox(width: 18),
          const Expanded(
            child: Text(
              'Сообщения',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          if (hasMessages)
            GestureDetector(
              onTap: onClearTap,
              child: const Icon(
                Icons.delete_outline,
                color: AppColors.danger,
                size: 27,
              ),
            ),
          if (hasMessages) const SizedBox(width: 16),
          GestureDetector(
            onTap: onSearchTap,
            child: const Icon(
              Icons.search,
              color: AppColors.primary,
              size: 28,
            ),
          ),
        ],
      ),
    );
  }
}