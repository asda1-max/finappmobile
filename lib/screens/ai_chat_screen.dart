import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import '../core/theme/app_colors.dart';
import '../core/api_client.dart';
import '../core/constants/api_constants.dart';
import '../core/services/local_db_service.dart';

/// AI-powered stock analyst chat screen.
///
/// Users can ask questions about their stocks in natural language.
/// The AI has full context of all tracked stocks' fundamental data.
class AiChatScreen extends StatefulWidget {
  const AiChatScreen({super.key});

  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen>
    with TickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  final List<_ChatMessage> _messages = [];
  bool _isLoading = false;
  bool _aiConfigured = true;
  String _modelName = 'Gemma 4 31B';

  // Quick suggestion chips
  static const _suggestions = [
    'Saham mana yang paling layak beli?',
    'Bandingkan 2 saham teratas di watchlist',
    'Analisis risiko portofolio saya',
    'Saham mana yang punya dividen terbaik?',
    'Jelaskan arti Hybrid Score',
  ];

  @override
  void initState() {
    super.initState();
    _checkAiStatus();
    _addWelcomeMessage();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _addWelcomeMessage() {
    _messages.add(_ChatMessage(
      text:
          'Halo! 👋 Selamat datang di Ticki TackAI, asisten analisis saham Anda.\n\n'
          'Saya bisa membantu:\n'
          '• 📊 Analisis fundamental saham di watchlist\n'
          '• 🔍 Menjelaskan keputusan BUY/NO BUY\n'
          '• ⚖️ Membandingkan saham\n'
          '• 💡 Memberikan insight investasi\n\n'
          'Tanyakan apa saja tentang saham kamu!',
      isUser: false,
      timestamp: DateTime.now(),
    ));
  }

  Future<void> _checkAiStatus() async {
    try {
      final response = await ApiClient.instance.get(ApiConstants.aiStatus);
      final data = response.data as Map<String, dynamic>;
      setState(() {
        _aiConfigured = data['configured'] as bool? ?? false;
        _modelName = _formatModelName(
          data['model'] as String? ?? 'google/gemma-4-31b-it',
        );
      });
    } catch (_) {
      // Silently fail — will show error when user sends message
    }
  }

  String _formatModelName(String rawModel) {
    // "google/gemma-4-31b-it" → "Gemma 4 31B"
    final parts = rawModel.split('/');
    final name = parts.length > 1 ? parts[1] : rawModel;
    return name
        .replaceAll('-it', '')
        .replaceAll('-', ' ')
        .split(' ')
        .map((w) => w.isNotEmpty
            ? '${w[0].toUpperCase()}${w.substring(1)}'
            : '')
        .join(' ');
  }

  Future<void> _sendMessage([String? overrideText]) async {
    final text = (overrideText ?? _controller.text).trim();
    if (text.isEmpty || _isLoading) return;

    // Add user message
    setState(() {
      _messages.add(_ChatMessage(
        text: text,
        isUser: true,
        timestamp: DateTime.now(),
      ));
      _isLoading = true;
    });
    _controller.clear();
    _scrollToBottom();

    try {
      final tickers = LocalDbService.getSavedTickers();
      final response = await ApiClient.instance.post(
        ApiConstants.aiChat,
        data: {
          'message': text,
          'tickers': tickers.isNotEmpty ? tickers : null,
        },
        options: Options(
          receiveTimeout: const Duration(seconds: 120),
          sendTimeout: const Duration(seconds: 30),
        ),
      );

      final data = response.data as Map<String, dynamic>;
      final aiResponse = data['response'] as String? ?? 'Tidak ada respons.';

      setState(() {
        _messages.add(_ChatMessage(
          text: aiResponse,
          isUser: false,
          timestamp: DateTime.now(),
        ));
      });
    } on DioException catch (e) {
      String errorMsg;
      if (e.response?.statusCode == 502) {
        errorMsg =
            '⚠️ Gagal menghubungi AI service.\n\n'
            'Pastikan OpenRouter API key sudah dikonfigurasi di `backend/.env`.';
      } else if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        errorMsg =
            '⏱️ Request timeout. AI sedang memproses — coba lagi dalam beberapa detik.';
      } else if (e.type == DioExceptionType.connectionError) {
        errorMsg =
            '🔌 Tidak bisa connect ke backend. Pastikan server berjalan.';
      } else {
        errorMsg =
            '❌ Error: ${e.response?.data?['detail'] ?? e.message ?? 'Unknown error'}';
      }

      setState(() {
        _messages.add(_ChatMessage(
          text: errorMsg,
          isUser: false,
          isError: true,
          timestamp: DateTime.now(),
        ));
      });
    } catch (e) {
      setState(() {
        _messages.add(_ChatMessage(
          text: '❌ Unexpected error: $e',
          isUser: false,
          isError: true,
          timestamp: DateTime.now(),
        ));
      });
    } finally {
      setState(() => _isLoading = false);
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _clearChat() {
    setState(() {
      _messages.clear();
      _addWelcomeMessage();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ──
            _buildHeader(),
            // ── AI not configured banner ──
            if (!_aiConfigured) _buildConfigBanner(),
            // ── Messages ──
            Expanded(child: _buildMessageList()),
            // ── Suggestion chips (only when few messages) ──
            if (_messages.length <= 2) _buildSuggestions(),
            // ── Input bar ──
            _buildInputBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.forum_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShaderMask(
                  shaderCallback: (bounds) =>
                      AppColors.primaryGradient.createShader(bounds),
                  child: const Text(
                    'Ticki TackAI',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
                Text(
                  _modelName,
                  style: TextStyle(
                    fontSize: 10,
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          // Online indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _aiConfigured
                  ? AppColors.buyGreen.withValues(alpha: 0.12)
                  : AppColors.sellRed.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: _aiConfigured
                        ? AppColors.buyGreen
                        : AppColors.sellRed,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  _aiConfigured ? 'Online' : 'Offline',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: _aiConfigured
                        ? AppColors.buyGreen
                        : AppColors.sellRed,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Clear chat button
          GestureDetector(
            onTap: _clearChat,
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.delete_outline_rounded,
                size: 16,
                color: AppColors.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfigBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.holdAmberBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppColors.holdAmber.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded,
              size: 16, color: AppColors.holdAmber),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'API key belum dikonfigurasi. Set OPENROUTER_API_KEY di backend/.env',
              style: TextStyle(
                fontSize: 11,
                color: AppColors.holdAmberLight,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageList() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      itemCount: _messages.length + (_isLoading ? 1 : 0),
      itemBuilder: (context, index) {
        // Typing indicator
        if (index == _messages.length && _isLoading) {
          return _buildTypingIndicator();
        }
        return _buildMessageBubble(_messages[index]);
      },
    );
  }

  Widget _buildMessageBubble(_ChatMessage message) {
    final isUser = message.isUser;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.82,
        ),
        margin: EdgeInsets.only(
          bottom: 10,
          left: isUser ? 40 : 0,
          right: isUser ? 0 : 40,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isUser
              ? AppColors.primary.withValues(alpha: 0.18)
              : message.isError
                  ? AppColors.sellRed.withValues(alpha: 0.08)
                  : AppColors.card,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: isUser
                ? const Radius.circular(16)
                : const Radius.circular(4),
            bottomRight: isUser
                ? const Radius.circular(4)
                : const Radius.circular(16),
          ),
          border: Border.all(
            color: isUser
                ? AppColors.primary.withValues(alpha: 0.2)
                : message.isError
                    ? AppColors.sellRed.withValues(alpha: 0.15)
                    : AppColors.cardBorder,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isUser)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      message.isError
                          ? Icons.error_outline_rounded
                          : Icons.forum_rounded,
                      size: 12,
                      color: message.isError
                          ? AppColors.sellRed
                          : AppColors.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      message.isError ? 'Error' : 'Analyst',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: message.isError
                            ? AppColors.sellRed
                            : AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            _RichTextContent(text: message.text),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _formatTime(message.timestamp),
                  style: TextStyle(
                    fontSize: 9,
                    color: AppColors.textMuted,
                  ),
                ),
                if (!isUser) ...[
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: message.text));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Copied to clipboard'),
                          backgroundColor: AppColors.surface,
                          behavior: SnackBarBehavior.floating,
                          duration: const Duration(seconds: 1),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      );
                    },
                    child: Icon(
                      Icons.copy_rounded,
                      size: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10, right: 80),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomLeft: Radius.circular(4),
            bottomRight: Radius.circular(16),
          ),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.forum_rounded, size: 12, color: AppColors.primary),
            const SizedBox(width: 8),
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Memproses...',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textTertiary,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestions() {
    return Container(
      height: 40,
      margin: const EdgeInsets.only(bottom: 4),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _suggestions.length,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ActionChip(
              label: Text(
                _suggestions[index],
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.primary,
                ),
              ),
              backgroundColor: AppColors.primary.withValues(alpha: 0.08),
              side: BorderSide(
                color: AppColors.primary.withValues(alpha: 0.2),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              onPressed: () => _sendMessage(_suggestions[index]),
            ),
          );
        },
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(
          top: BorderSide(color: AppColors.cardBorder),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textPrimary,
                ),
                maxLines: 3,
                minLines: 1,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendMessage(),
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  hintText: 'Ketik pertanyaan Anda...',
                  hintStyle: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 13,
                  ),
                  border: InputBorder.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _isLoading ? null : () => _sendMessage(),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: _isLoading ? null : AppColors.primaryGradient,
                color: _isLoading ? AppColors.surfaceLight : null,
                borderRadius: BorderRadius.circular(22),
              ),
              child: Icon(
                _isLoading
                    ? Icons.hourglass_top_rounded
                    : Icons.send_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

// ── Data Model ──

class _ChatMessage {
  final String text;
  final bool isUser;
  final bool isError;
  final DateTime timestamp;

  const _ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.isError = false,
  });
}

// ── Simple Markdown-like Rich Text ──

class _RichTextContent extends StatelessWidget {
  final String text;
  const _RichTextContent({required this.text});

  @override
  Widget build(BuildContext context) {
    // Parse basic markdown: **bold**, bullet points, numbered lists
    final lines = text.split('\n');
    final spans = <InlineSpan>[];

    for (int i = 0; i < lines.length; i++) {
      if (i > 0) spans.add(const TextSpan(text: '\n'));

      final line = lines[i];
      // Parse **bold** within each line
      final parts = _parseBold(line);
      spans.addAll(parts);
    }

    return Text.rich(
      TextSpan(children: spans),
      style: const TextStyle(
        fontSize: 13,
        color: AppColors.textPrimary,
        height: 1.5,
      ),
    );
  }

  List<InlineSpan> _parseBold(String text) {
    final spans = <InlineSpan>[];
    final regex = RegExp(r'\*\*(.+?)\*\*');
    int lastEnd = 0;

    for (final match in regex.allMatches(text)) {
      if (match.start > lastEnd) {
        spans.add(TextSpan(text: text.substring(lastEnd, match.start)));
      }
      spans.add(TextSpan(
        text: match.group(1),
        style: const TextStyle(fontWeight: FontWeight.w700),
      ));
      lastEnd = match.end;
    }

    if (lastEnd < text.length) {
      spans.add(TextSpan(text: text.substring(lastEnd)));
    }

    if (spans.isEmpty) {
      spans.add(TextSpan(text: text));
    }

    return spans;
  }
}
