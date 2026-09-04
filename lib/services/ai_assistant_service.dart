/// AiAssistantService — Phase 2 Placeholder
///
/// Modular architecture for future AI chatbot integration.
/// Currently provides:
///   • Structured message types ready for LLM routing
///   • Context-aware prompt builder stubs
///   • Role-specific assistant personalities (Donor / Receiver / NGO / Volunteer)
///   • Integration hooks for Gemini / OpenAI / Dialogflow
///
/// To activate: replace _mockResponse() with a real API call.
library;

// ─────────────────────────────────────────────────────────────────────────────
// Message types
// ─────────────────────────────────────────────────────────────────────────────

enum AssistantRole {
  donor,
  receiver,
  ngo,
  volunteer,
}

enum MessageType {
  text,
  suggestion,     // clickable quick-reply chip
  foodGuidance,   // food safety tip card
  navigationHint, // volunteer route suggestion
  escalation,     // urgent action required
}

class AssistantMessage {
  final String content;
  final MessageType type;
  final bool isFromUser;
  final DateTime timestamp;
  final List<String> suggestions; // quick reply chips

  AssistantMessage({
    required this.content,
    this.type = MessageType.text,
    this.isFromUser = false,
    this.suggestions = const [],
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

// ─────────────────────────────────────────────────────────────────────────────
// Service
// ─────────────────────────────────────────────────────────────────────────────

class AiAssistantService {
  final AssistantRole role;
  final List<AssistantMessage> _history = [];

  AiAssistantService({required this.role});

  List<AssistantMessage> get history => List.unmodifiable(_history);

  // ── SEND MESSAGE ──────────────────────────────────────────────────────────

  /// Send a user message and receive an AI response.
  /// Replace [_mockResponse] with a real LLM call.
  Future<AssistantMessage> send(String userMessage) async {
    final userMsg = AssistantMessage(
      content: userMessage,
      isFromUser: true,
      type: MessageType.text,
    );
    _history.add(userMsg);

    final response = await _mockResponse(userMessage);
    _history.add(response);
    return response;
  }

  // ── CONTEXT-AWARE PROMPT BUILDER ──────────────────────────────────────────

  /// Builds a system prompt personalized to the user's role.
  /// This will be prepended to every LLM API call.
  String buildSystemPrompt() {
    const base = 'You are an AI assistant for the LeftOver Food App, '
        'a community food rescue platform. Be concise, compassionate, and helpful. '
        'Always prioritize food safety and community well-being.';

    return switch (role) {
      AssistantRole.donor => '$base You are helping a DONOR. Guide them on '
          'food safety, proper donation practices, and how to post food donations '
          'correctly. Discourage unsafe food donations.',
      AssistantRole.receiver => '$base You are helping a RECEIVER. Help them '
          'find available food, understand pickup instructions, and make requests. '
          'Be sensitive and respectful.',
      AssistantRole.ngo => '$base You are helping an NGO COORDINATOR. Provide '
          'insights on donation management, volunteer coordination, and optimizing '
          'food distribution efficiency.',
      AssistantRole.volunteer => '$base You are helping a VOLUNTEER. Guide them '
          'on task acceptance, safe food handling during delivery, navigation, '
          'and reporting issues.',
    };
  }

  // ── ROLE-SPECIFIC QUICK STARTERS ─────────────────────────────────────────

  /// Returns contextual quick-reply suggestions based on role.
  List<String> getQuickSuggestions() {
    return switch (role) {
      AssistantRole.donor => [
          'How do I post food safely?',
          'What food can I donate?',
          'How does AI check my food?',
          'Can I cancel a post?',
        ],
      AssistantRole.receiver => [
          'How do I request food?',
          'Where is my pickup?',
          'What food is available now?',
          'Update my food preferences',
        ],
      AssistantRole.ngo => [
          'How do I claim a donation?',
          'Assign volunteer to task',
          'Show urgent donations',
          'View AI analytics',
        ],
      AssistantRole.volunteer => [
          'Show my tasks',
          'How do I deliver safely?',
          'Mark task as delivered',
          'Report a problem',
        ],
    };
  }

  // ── FOOD SAFETY GUIDANCE ─────────────────────────────────────────────────

  /// Returns a food-safety tip card for a given food category.
  /// TODO: Replace with dynamic Gemini call for personalized tips.
  static AssistantMessage getFoodSafetyTip(String category) {
    const tips = <String, String>{
      'meat':
          '🥩 Meat must be kept below 4°C at all times. Donate only if cooked or freshly stored. Never donate if more than 2 days old after cooking.',
      'dairy':
          '🥛 Dairy spoils quickly. Check for off-smell or texture changes. Donate only if sealed and within expiry date.',
      'cookedMeals':
          '🍱 Cooked meals are high-risk. Donate within 2–3 hours of cooking. Keep hot foods above 60°C during transport.',
      'fruits':
          '🍎 Fresh fruit is generally safe. Remove visibly moldy pieces. Store separately from cooked items.',
      'bakery':
          '🍞 Bakery items are safe for 1–2 days. Avoid if mold is visible. Keep dry and sealed.',
      'vegetables':
          '🥦 Vegetables are safe if firm and brightly colored. Wilted or mushy is borderline — donate quickly.',
    };

    return AssistantMessage(
      content: tips[category] ?? '🌱 Always ensure donated food is fresh, properly stored, and within safe consumption time.',
      type: MessageType.foodGuidance,
      suggestions: ['Tell me more', 'Check other categories', 'Post a donation'],
    );
  }

  // ── MOCK RESPONSE ─────────────────────────────────────────────────────────

  /// PLACEHOLDER: Replace with real Gemini / OpenAI API call.
  ///
  /// TODO: Implement _realGeminiChat(userMessage, history)
  /// TODO: Implement _dialogflowSession()
  /// TODO: Implement voice input / TTS output for accessibility
  Future<AssistantMessage> _mockResponse(String input) async {
    await Future.delayed(const Duration(milliseconds: 800));
    final lower = input.toLowerCase();

    if (lower.contains('food') && lower.contains('safe')) {
      return AssistantMessage(
        content: 'Great question! Our AI scans every donated food image for freshness. '
            'If food is flagged as unsafe, the upload is automatically blocked to protect recipients.',
        suggestions: ['Learn more', 'Post a donation'],
        type: MessageType.foodGuidance,
      );
    }
    if (lower.contains('urgent') || lower.contains('expir')) {
      return AssistantMessage(
        content: '⚡ Urgent donations are automatically escalated to NGOs and sorted to the top of receiver feeds. '
            'Volunteers are notified immediately.',
        suggestions: ['Show urgent posts', 'Contact NGO'],
        type: MessageType.escalation,
      );
    }
    return AssistantMessage(
      content: 'I\'m here to help! You can ask me about food donations, '
          'pickup instructions, AI safety checks, or volunteer tasks.',
      suggestions: getQuickSuggestions().take(3).toList(),
    );
  }
}

