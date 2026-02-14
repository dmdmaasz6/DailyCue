import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/chat_message.dart';
import '../providers/ai_chat_provider.dart';
import '../utils/constants.dart';
import '../widgets/chat_message_bubble.dart';
import 'settings_screen.dart';

class AiChatScreen extends StatefulWidget {
  const AiChatScreen({super.key});

  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _sendMessage(AiChatProvider provider) {
    final text = _textController.text.trim();
    if (text.isEmpty || provider.isGenerating) return;

    _textController.clear();
    provider.sendMessage(text);
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AiChatProvider>(
      builder: (context, provider, _) {
        final showApiKeySetup = !provider.isReady;

        return Scaffold(
          appBar: AppBar(
            title: Row(
              children: [
                Icon(
                  Icons.auto_awesome,
                  size: AppIconSizes.sm,
                  color: AppColors.primary,
                ),
                const SizedBox(width: AppSpacing.sm),
                const Text('AI Coach'),
              ],
            ),
            actions: [
              if (!showApiKeySetup && provider.messages.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _showClearDialog(context, provider),
                  tooltip: 'Clear chat',
                ),
            ],
          ),
          body: showApiKeySetup
              ? _ApiKeySetupCard(
                  onOpenSettings: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const SettingsScreen(),
                      ),
                    );
                  },
                )
              : Column(
                  children: [
                    // Chat messages
                    Expanded(
                      child: provider.messages.isEmpty
                          ? _EmptyState(
                              onSuggestionTap: (text) {
                                _textController.text = text;
                                _sendMessage(provider);
                              },
                            )
                          : _buildMessageList(provider),
                    ),

                    // Confirmation card (if pending)
                    if (provider.hasPendingConfirmation &&
                        provider.pendingToolName != null)
                      ToolConfirmationCard(
                        toolName: provider.pendingToolName!,
                        arguments: provider.pendingToolArgs ?? {},
                        onApprove: () =>
                            provider.confirmToolAction(true),
                        onDecline: () =>
                            provider.confirmToolAction(false),
                      ),

                    // Input bar
                    _InputBar(
                      controller: _textController,
                      focusNode: _focusNode,
                      isGenerating: provider.isGenerating,
                      onSend: () => _sendMessage(provider),
                      onStop: () => provider.stopGeneration(),
                    ),
                  ],
                ),
        );
      },
    );
  }

  Widget _buildMessageList(AiChatProvider provider) {
    // Filter out tool results from display
    final displayMessages = provider.messages
        .where(
            (m) => m.role != ChatRole.toolResult && m.role != ChatRole.system)
        .toList();

    _scrollToBottom();

    return ListView.builder(
      controller: _scrollController,
      padding:
          const EdgeInsets.only(top: AppSpacing.sm, bottom: AppSpacing.sm),
      itemCount: displayMessages.length + (provider.isGenerating ? 1 : 0),
      itemBuilder: (context, index) {
        if (index < displayMessages.length) {
          return ChatMessageBubble(message: displayMessages[index]);
        }
        // Typing indicator
        return const _TypingIndicator();
      },
    );
  }

  void _showClearDialog(BuildContext context, AiChatProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear chat'),
        content: const Text(
            'This will delete all messages. This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              provider.clearChat();
              Navigator.pop(ctx);
            },
            child: Text(
              'Clear',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// API key setup card (shown when no API key is configured)
// ---------------------------------------------------------------------------

class _ApiKeySetupCard extends StatelessWidget {
  final VoidCallback onOpenSettings;

  const _ApiKeySetupCard({required this.onOpenSettings});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.info.withOpacity(0.1),
                borderRadius: AppRadii.borderRadiusFull,
              ),
              child: const Icon(
                Icons.vpn_key_outlined,
                size: 28,
                color: AppColors.info,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'API Key Required',
              style: AppTypography.headingMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Enter your OpenAI API key in Settings to start chatting with your AI Coach.',
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),
            ElevatedButton.icon(
              onPressed: onOpenSettings,
              icon: const Icon(Icons.settings_outlined, size: 18),
              label: const Text('Open Settings'),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Your API key is stored only on this device.',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textTertiary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Empty state with suggestion chips
// ---------------------------------------------------------------------------

class _EmptyState extends StatelessWidget {
  final void Function(String text) onSuggestionTap;

  const _EmptyState({
    required this.onSuggestionTap,
  });

  static const _suggestions = [
    'How is my balance this week?',
    'What should I focus on today?',
    'Suggest a new habit for me',
    'Which area am I strongest in?',
  ];

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: AppRadii.borderRadiusFull,
              ),
              child: const Icon(
                Icons.auto_awesome,
                size: 28,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Your AI Coach',
              style: AppTypography.headingMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Ask about your habits, get personalized insights, or let me help you build a more balanced routine.',
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              alignment: WrapAlignment.center,
              children: _suggestions.map((text) {
                return ActionChip(
                  label: Text(text, style: AppTypography.bodySmall),
                  onPressed: () => onSuggestionTap(text),
                  backgroundColor: AppColors.surface,
                  side: const BorderSide(color: AppColors.border),
                  shape: RoundedRectangleBorder(
                    borderRadius: AppRadii.borderRadiusFull,
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Input bar
// ---------------------------------------------------------------------------

class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isGenerating;
  final VoidCallback onSend;
  final VoidCallback onStop;

  const _InputBar({
    required this.controller,
    required this.focusNode,
    required this.isGenerating,
    required this.onSend,
    required this.onStop,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: AppSpacing.md,
        right: AppSpacing.sm,
        top: AppSpacing.sm,
        bottom: MediaQuery.of(context).padding.bottom + AppSpacing.sm,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(
          top: BorderSide(color: AppColors.border),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              enabled: !isGenerating,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => onSend(),
              maxLines: 4,
              minLines: 1,
              decoration: InputDecoration(
                hintText: isGenerating
                    ? 'Thinking...'
                    : 'Ask about your habits...',
                filled: true,
                fillColor: AppColors.surfaceAlt,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: 10,
                ),
                border: OutlineInputBorder(
                  borderRadius: AppRadii.borderRadiusFull,
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: AppRadii.borderRadiusFull,
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: AppRadii.borderRadiusFull,
                  borderSide:
                      const BorderSide(color: AppColors.primary, width: 1.5),
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          isGenerating
              ? IconButton(
                  onPressed: onStop,
                  icon: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.error,
                      borderRadius: AppRadii.borderRadiusFull,
                    ),
                    child: const Icon(
                      Icons.stop,
                      size: 20,
                      color: Colors.white,
                    ),
                  ),
                )
              : IconButton(
                  onPressed: onSend,
                  icon: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: AppRadii.borderRadiusFull,
                    ),
                    child: const Icon(
                      Icons.arrow_upward,
                      size: 20,
                      color: Colors.white,
                    ),
                  ),
                ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Typing indicator
// ---------------------------------------------------------------------------

class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator();

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        left: AppSpacing.md,
        right: 48,
        top: AppSpacing.xs,
        bottom: AppSpacing.xs,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: AppRadii.borderRadiusFull,
            ),
            child: const Icon(
              Icons.auto_awesome,
              size: 16,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(AppRadii.sm),
                topRight: const Radius.circular(AppRadii.lg),
                bottomLeft: const Radius.circular(AppRadii.lg),
                bottomRight: const Radius.circular(AppRadii.lg),
              ),
              border: Border.all(color: AppColors.border),
            ),
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(3, (i) {
                    final delay = i * 0.2;
                    final value = ((_controller.value + delay) % 1.0);
                    final opacity = value < 0.5
                        ? 0.3 + (value * 2 * 0.7)
                        : 1.0 - ((value - 0.5) * 2 * 0.7);
                    return Padding(
                      padding:
                          EdgeInsets.only(right: i < 2 ? 4 : 0),
                      child: Opacity(
                        opacity: opacity,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: AppColors.textTertiary,
                            borderRadius: AppRadii.borderRadiusFull,
                          ),
                        ),
                      ),
                    );
                  }),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
