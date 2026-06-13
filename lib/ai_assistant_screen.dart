import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

class AiAssistantScreen extends StatefulWidget {
  final List<Map<String, String>> dataList;
  final List<String> permittedColumns;
  final String accessPermissions;
  final String sheetName;

  const AiAssistantScreen({
    super.key,
    required this.dataList,
    required this.permittedColumns,
    required this.accessPermissions,
    required this.sheetName,
  });

  @override
  State<AiAssistantScreen> createState() => _AiAssistantScreenState();
}

class _AiAssistantScreenState extends State<AiAssistantScreen> {
  final TextEditingController _promptController = TextEditingController();
  static final List<Map<String, String>> _messages = [];
  bool _isTyping = false;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    if (_messages.isEmpty) {
      _messages.add({
        'sender': 'ai',
        'text':
            'Hello! I am your AI Assistant. I strictly follow your security permissions. I currently have access to ${widget.permittedColumns.length} columns in the "${widget.sheetName}" workspace. How can I help you today?',
      });
    }
  }

  void _sendMessage() async {
    final prompt = _promptController.text.trim();
    if (prompt.isEmpty) return;

    setState(() {
      _messages.add({'sender': 'user', 'text': prompt});
      _promptController.clear();
      _isTyping = true;
    });
    _scrollToBottom();

    String aiResponse = "";

    // AI Check 1: Does the user have read access at all?
    if (!widget.accessPermissions.toLowerCase().contains('read')) {
      aiResponse =
          "🚫 Security Alert\n\nIt looks like you don't have 'Read' permissions for this workspace. I cannot process any data queries for you here.";
      _completeMessage(aiResponse);
      return;
    }

    try {
      // 1. FILTER THE DATA
      // We must strip out any columns the user does NOT have permission to view
      // before sending the data to the AI model. This ensures absolute security.
      List<Map<String, String>> secureDataList = [];
      for (var row in widget.dataList) {
        Map<String, String> secureRow = {};
        
        // ALWAYS include the Date column so the AI knows WHEN things happened
        final dateKey = row.keys.firstWhere((k) => k.toLowerCase().contains('date'), orElse: () => '');
        if (dateKey.isNotEmpty && row[dateKey] != null) {
           secureRow[dateKey] = row[dateKey]!;
        }

        for (var col in widget.permittedColumns) {
          final actualKey = row.keys.firstWhere(
            (k) => k.toLowerCase() == col.toLowerCase(),
            orElse: () => '',
          );
          if (actualKey.isNotEmpty) {
            secureRow[actualKey] = row[actualKey]!;
          }
        }
        if (secureRow.isNotEmpty) {
          secureDataList.add(secureRow);
        }
      }

      // 2. CONNECT TO GEMINI
      const apiKey = String.fromEnvironment('GEMINI_API_KEY', defaultValue: 'YOUR_API_KEY_HERE');

      if (apiKey == 'YOUR_API_KEY_HERE') {
        aiResponse =
            "⚠️ Developer Setup Required:\n\nPlease run the app with --dart-define=GEMINI_API_KEY=your_api_key to activate real AI responses.\n\nFor now, your filtered data contains ${secureDataList.length} secure rows with columns: ${widget.permittedColumns.join(', ')}.";
        _completeMessage(aiResponse);
        return;
      }

      final model = GenerativeModel(
        model: 'gemini-2.5-flash', 
        apiKey: apiKey,
      );

      // 3. BUILD THE PROMPT CONTEXT
      final systemContext =
          '''
You are a helpful, professional AI Assistant built into a business app.
You are helping a user analyze data from the "${widget.sheetName}" workspace.
CRITICAL SECURITY RULE: You only have access to the data provided below in JSON format. This data has already been securely filtered based on the user's permissions. Do NOT attempt to guess or hallucinate data that isn't provided.
If the user asks about a column or data point not in the JSON below, tell them they do not have permission to view it or it does not exist.

Here is the secure data you are allowed to analyze:
$secureDataList

Please answer the user's prompt based ONLY on the data above. Be concise, friendly, and use formatting/emojis where appropriate.
User Prompt: "$prompt"
''';

      // 4. GET RESPONSE FROM GEMINI
      final content = [Content.text(systemContext)];
      final response = await model.generateContent(content);

      aiResponse =
          response.text?.trim() ??
          "I'm sorry, I couldn't generate a response. Please try again.";
    } catch (e) {
      aiResponse = "⚠️ Network Error:\n\nThere was an issue connecting to the AI. Please make sure your internet is connected. ($e)";
    }

    _completeMessage(aiResponse);
  }

  void _completeMessage(String responseText) {
    if (mounted) {
      setState(() {
        _isTyping = false;
        _messages.add({'sender': 'ai', 'text': responseText});
      });
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 100,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.fromLTRB(24, 60, 24, 24),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.8),
            border: Border(
              bottom: BorderSide(
                color: Colors.grey.withValues(alpha: 0.2),
                width: 1,
              ),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF667EEA), Color(0xFF8B5CF6)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF667EEA).withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'AI Assistant',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF2D3748),
                        letterSpacing: -0.5,
                      ),
                    ),
                    Text(
                      'Strict Security Enforced \u2022 ${widget.sheetName}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF10B981), // Emerald green
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(duration: 400.ms).slideX(begin: 0.1),
            ],
          ),
        ),

        // Chat Area
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.fromLTRB(
              16,
              16,
              16,
              100,
            ), // padding for bottom nav
            itemCount: _messages.length + (_isTyping ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == _messages.length) {
                return _buildTypingIndicator();
              }
              final msg = _messages[index];
              final isAi = msg['sender'] == 'ai';
              return _buildMessageBubble(msg['text']!, isAi);
            },
          ),
        ),

        // Input Area
        Container(
          padding: const EdgeInsets.fromLTRB(
            16,
            12,
            16,
            120,
          ), // Extra bottom padding for nav bar
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.8),
            border: Border(
              top: BorderSide(
                color: Colors.grey.withValues(alpha: 0.2),
                width: 1,
              ),
            ),
          ),
          child: SafeArea(
            top: false,
            bottom: false,
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: Colors.grey.withValues(alpha: 0.2),
                      ),
                    ),
                    child: TextField(
                      controller: _promptController,
                      style: const TextStyle(
                        fontSize: 15,
                        color: Colors.black87,
                      ),
                      decoration: const InputDecoration(
                        hintText: 'Ask about your secure data...',
                        hintStyle: TextStyle(color: Colors.grey),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 14,
                        ),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: _sendMessage,
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF667EEA), Color(0xFF8B5CF6)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.send_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ).animate().scale(duration: 200.ms),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMessageBubble(String text, bool isAi) {
    return Align(
      alignment: isAi ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: isAi ? Colors.white : const Color(0xFF667EEA),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: Radius.circular(isAi ? 4 : 20),
            bottomRight: Radius.circular(isAi ? 20 : 4),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 15,
            height: 1.4,
            color: isAi ? const Color(0xFF334155) : Colors.white,
            fontWeight: isAi ? FontWeight.w500 : FontWeight.w600,
          ),
        ),
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.1);
  }

  Widget _buildTypingIndicator() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
            bottomLeft: Radius.circular(4),
            bottomRight: Radius.circular(20),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDot(0),
            const SizedBox(width: 4),
            _buildDot(1),
            const SizedBox(width: 4),
            _buildDot(2),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 200.ms);
  }

  Widget _buildDot(int index) {
    return Animate(
      onPlay: (controller) => controller.repeat(),
      child:
          Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: const Color(0xFF667EEA).withValues(alpha: 0.6),
                  shape: BoxShape.circle,
                ),
              )
              .animate()
              .fade(duration: 400.ms, delay: (index * 150).ms)
              .scale(begin: const Offset(0.5, 0.5), end: const Offset(1, 1)),
    );
  }
}
