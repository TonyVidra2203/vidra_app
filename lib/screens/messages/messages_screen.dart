import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../navigation/app_routes.dart';
import '../../services/messages_mock_data.dart';
import '../../widgets/common/app_bottom_nav_bar.dart';
import '../../widgets/messages/message_list.dart';
import '../../widgets/messages/message_filter_bar.dart';
import '../../models/message_filter_model.dart';
import '../../models/message_model.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  MessageFilter selectedFilter = MessageFilter.all;
  bool isSearchOpen = false;
  String searchQuery = '';

  List<MessageModel> get filteredMessages {
    List<MessageModel> messages = MessagesMockData.messages;

    switch (selectedFilter) {
      case MessageFilter.sms:
        messages = messages.where((m) => m.type == MessageType.sms).toList();
        break;
      case MessageFilter.push:
        messages = messages.where((m) => m.type == MessageType.push).toList();
        break;
      case MessageFilter.errors:
        messages = messages.where((m) => m.status == MessageStatus.error).toList();
        break;
      case MessageFilter.all:
        break;
    }

    if (searchQuery.trim().isNotEmpty) {
      final query = searchQuery.toLowerCase().trim();

      messages = messages.where((m) {
        return m.sender.toLowerCase().contains(query) ||
            m.text.toLowerCase().contains(query) ||
            m.deviceName.toLowerCase().contains(query);
      }).toList();
    }

    return messages;
  }

  void toggleSearch() {
    setState(() {
      isSearchOpen = !isSearchOpen;

      if (!isSearchOpen) {
        searchQuery = '';
      }
    });
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
              onSearchTap: toggleSearch,
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
              child: MessageList(messages: filteredMessages),
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
  final String searchQuery;
  final VoidCallback onSearchTap;
  final ValueChanged<String> onSearchChanged;

  const _Header({
    required this.isSearchOpen,
    required this.searchQuery,
    required this.onSearchTap,
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
          const Icon(Icons.menu, color: AppColors.primary, size: 32),
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