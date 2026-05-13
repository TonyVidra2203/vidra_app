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
      _loadMessages(showLoader: false);
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
      _loadMessages(showLoader: false);
    });
  }

  void _startAutoRefresh() {
    refreshTimer?.cancel();

    refreshTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _loadMessages(showLoader: false);
    });
  }

  Future<void> _loadMessages({bool showLoader = true}) async {
    if (isRefreshing) {
      return;
    }

    isRefreshing = true;

    try {
      final nativeMessages = await nativeService.getMessages();

      if (!mounted) {
        return;
      }

      final newMessages = nativeMessages.map(_mapNativeMessage).toList();

      setState(() {
        messages = newMessages;
        isLoading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      if (showLoader || isLoading) {
        setState(() => isLoading = false);
      }
    } finally {
      isRefreshing = false;
    }
  }

  MessageModel _mapNativeMessage(NativeForwardedMessage message) {
    final date = DateTime.fromMillisecondsSinceEpoch(message.receivedAt);

    return MessageModel(
      sender: message.displayTitle,
      text: message.displaySubtitle,
      deviceName:
      message.deviceName.isEmpty ? 'Рабочий телефон' : message.deviceName,
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
    await _loadMessages(showLoader: false);
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
                setState(() => searchQuery = value);
              },
            ),
            MessageFilterBar(
              selectedFilter: selectedFilter,
              onChanged: (filter) {
                setState(() => selectedFilter = filter);
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

class _Header extends StatefulWidget {
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
  State<_Header> createState() => _HeaderState();
}

class _HeaderState extends State<_Header> {
  late final TextEditingController searchController;

  @override
  void initState() {
    super.initState();
    searchController = TextEditingController(text: widget.searchQuery);
  }

  @override
  void didUpdateWidget(covariant _Header oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.searchQuery != searchController.text) {
      searchController.text = widget.searchQuery;
      searchController.selection = TextSelection.collapsed(
        offset: searchController.text.length,
      );
    }
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isSearchOpen) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
          decoration: BoxDecoration(
            color: AppColors.card.withOpacity(0.9),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.cardBorder),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.search,
                color: AppColors.primary,
                size: 22,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  autofocus: true,
                  controller: searchController,
                  onChanged: widget.onSearchChanged,
                  style: const TextStyle(color: AppColors.textPrimary),
                  cursorColor: AppColors.primary,
                  decoration: const InputDecoration(
                    hintText: 'Поиск сообщений...',
                    hintStyle: TextStyle(color: AppColors.textSecondary),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              _HeaderIconButton(
                icon: Icons.close,
                onTap: widget.onSearchTap,
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.card.withOpacity(0.9),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.14),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.primary.withOpacity(0.35),
                ),
              ),
              child: const Icon(
                Icons.chat_bubble_outline,
                color: AppColors.primary,
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Сообщения',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 3),
                  Text(
                    'SMS и PUSH с главного телефона',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      height: 1.25,
                    ),
                  ),
                ],
              ),
            ),
            if (widget.hasMessages) ...[
              _HeaderIconButton(
                icon: Icons.delete_outline,
                color: AppColors.danger,
                onTap: widget.onClearTap,
              ),
              const SizedBox(width: 8),
            ],
            _HeaderIconButton(
              icon: Icons.search,
              onTap: widget.onSearchTap,
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _HeaderIconButton({
    required this.icon,
    required this.onTap,
    this.color = AppColors.primary,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.background.withOpacity(0.45),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(
            icon,
            color: color,
            size: 22,
          ),
        ),
      ),
    );
  }
}