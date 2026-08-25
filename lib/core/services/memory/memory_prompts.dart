/// Memory prompt language for model-facing contracts (not UI l10n / ARB).
enum MemoryPromptLang { zh, en }

/// Built-in default prompt templates and pure time helpers for the memory system.
///
/// These strings are model contracts and must NOT go through ARB (§16.2).
abstract final class MemoryPrompts {
  MemoryPrompts._();

  // ── §11.2 / §11.3 memory rules ───────────────────────────────────────────

  static final String rulesZh =
      '''
## 长期记忆

对话中可能出现由系统提供的记忆信息，它们不是用户本轮说的话：

- <user_profile> 是用户的稳定身份信息，例如希望你怎么称呼他、语言偏好、时区。
- <user_memory type="..."> 是分四类的长期记忆。每行形如 `- [2026-08-07] 内容`，方括号里是这条记忆最后更新的日期。带 `(assistant) ` 前缀的条目只属于当前助手，其余对所有助手可见。
- 标了 mode="summary" 的块表示该类型共有 total 属性标明的条数，只列出了 shown 属性指明的最近若干条；需要更多时用 memory_search_profile 查询。
- 形如 <user_memory type="voice"/> 的空标签表示该类型目前没有记忆。
- 对话进行中出现的 <user_memory_update> 是记忆的最新完整快照，用它替换你之前看到的记忆内容。

称呼用户时，如果 <user_profile> 里有 preferred_name 就按它称呼；没有就不要猜测，也不要使用记忆中出现过的其他人的名字。

当用户透露了跨对话仍然成立的稳定信息时，用 memory_update 写一条记忆。判断标准是：下次重新开一个对话，不知道这件事会不会让你的回答变差。

不要写入：本次对话内的临时上下文、你自己推断而用户没有确认的结论、用户只是随口提到的话题、可以直接从对话记录里查到的事实。

写入时用完整的第三人称陈述句描述用户，不要使用「这个」「刚才」等指回本次对话的词。系统会自动去重合并，不需要先读取再全文替换。

用户明确指出某条记忆不对时，用 memory_edit 修改，或用 memory_delete 归档。
'''
          .trim();

  static final String rulesEn =
      '''
## Long-term memory

The conversation may contain memory information provided by the system. It is not what the user said in the current turn:

- <user_profile> holds stable facts about the user, such as how they want to be addressed, language preference and timezone.
- <user_memory type="..."> holds long-term memory in four categories. Each line looks like `- [2026-08-07] content`, where the bracket is the date this entry was last updated. Entries prefixed with `(assistant) ` belong only to the current assistant; the rest are visible to all assistants.
- A block marked mode="summary" means the category has the number of entries given by the total attribute, and only the most recent ones indicated by the shown attribute are listed. Use memory_search_profile when you need more.
- An empty tag such as <user_memory type="voice"/> means the category currently has no entries.
- A <user_memory_update> appearing mid-conversation is the latest complete snapshot. Replace the memory you saw earlier with it.

When addressing the user, use preferred_name from <user_profile> if present. Otherwise do not guess, and never use the name of another person that appears in memory.

When the user reveals something that will still be true in a different conversation, write one entry with memory_update. The test is: if you started a fresh conversation, would not knowing this make your answer worse?

Do not write: temporary context from this conversation, conclusions you inferred but the user did not confirm, topics the user merely mentioned in passing, or facts that can be looked up directly in the chat history.

Write complete third-person statements about the user. Do not use words like "this" or "just now" that point back to the current conversation. The system deduplicates and merges automatically, so you do not need to read first and rewrite the whole entry.

When the user says an entry is wrong, use memory_edit to fix it or memory_delete to archive it.
'''
          .trim();

  static final String legacyRulesZh =
      '''
## Memory Tool
你是一个无状态的大模型，你无法存储记忆，因此为了记住信息，你需要使用**记忆工具**。
你可以使用 `create_memory`, `edit_memory`, `delete_memory` 工具创建、更新或删除记忆。
- 如果记忆中没有相关信息，请使用 create_memory 创建一条新的记录。
- 如果已有相关记录，请使用 edit_memory 更新内容。
- 若记忆过时或无用，请使用 delete_memory 删除。
这些记忆会自动包含在未来的对话上下文中，在<memories>标签内。
请勿在记忆中存储敏感信息，敏感信息包括：用户的民族、宗教信仰、性取向、政治观点及党派归属、性生活、犯罪记录等。
在与用户聊天过程中，你可以像一个私人秘书一样**主动的**记录用户相关的信息到记忆里，包括但不限于：
- 用户昵称/姓名
- 年龄/性别/兴趣爱好
- 计划事项等
- 聊天风格偏好
- 工作相关
- 首次聊天时间
- ...
请主动调用工具记录，而不是需要用户要求。
记忆如果包含日期信息，请包含在内，请使用绝对时间格式，并且当前时间是{{currentTime}}。
无需告知用户你已更改记忆记录，也不要在对话中直接显示记忆内容，除非用户主动要求。
相似或相关的记忆应合并为一条记录，而不要重复记录，过时记录应删除。
你可以在和用户闲聊的时候暗示用户你能记住东西。
'''
          .trim();

  /// English counterpart of [legacyRulesZh].
  static final String legacyRulesEn =
      '''
## Memory Tool
You are a stateless model and cannot retain memories on your own; to remember something, use the **memory tools**.
Use the `create_memory`, `edit_memory`, and `delete_memory` tools to create, update, or delete memories.
- If nothing relevant is stored yet, use create_memory to add a new entry.
- If a related entry already exists, use edit_memory to update it.
- If an entry is outdated or useless, use delete_memory to remove it.
These memories are automatically included in future conversation context, inside the <memories> tag.
Never store sensitive information, which includes the user's ethnicity, religious beliefs, sexual orientation, political views and party affiliation, sex life, and criminal record.
While chatting with the user, act like a personal secretary and **proactively** record information about them, including but not limited to:
- Nickname / name
- Age / gender / interests
- Plans and scheduled items
- Preferred chat style
- Work-related details
- Time of the first conversation
- ...
Call the tools on your own initiative rather than waiting for the user to ask.
When an entry involves dates, include them in an absolute time format; the current time is {{currentTime}}.
There is no need to tell the user you changed an entry, and do not show memory contents in the conversation unless the user asks.
Similar or related memories should be merged into one entry instead of duplicated, and outdated entries should be deleted.
You may hint during casual chat that you are able to remember things.
'''
          .trim();

  static const String legacyCurrentTimePlaceholder = '{{currentTime}}';

  /// Appended to [rulesZh] when `allowPastConversationRecall` is on.
  static const String rulesPastConversationRecallZh =
      '需要回忆之前聊过的内容时，用 chat_search 按关键词搜索历史对话，不要凭印象作答。';

  /// Appended to [rulesEn] when `allowPastConversationRecall` is on.
  static const String rulesPastConversationRecallEn =
      'When you need to recall something discussed before, use chat_search to search past conversations by keyword. Do not answer from impression.';

  // ── §12.4 Gatekeeper ─────────────────────────────────────────────────────

  static final String gateZh =
      '''
分析以下对话，判断其中是否包含值得长期记忆的用户信息。

值得记忆：用户透露了个人信息、做事偏好、表达风格特征、对助手的明确要求
不值得：纯技术问答、项目细节、一次性操作指令

输出格式（严格按此 XML，不要输出多余文字）：
<gate>
  <user_memory>true 或 false</user_memory>
</gate>

## 对话
{{conversation}}
'''
          .trim();

  static final String gateEn =
      '''
Analyse the conversation below and decide whether it contains user information worth remembering long term.

Worth remembering: the user revealed personal information, a way of working, a characteristic of how they express themselves, or an explicit requirement for the assistant.
Not worth remembering: pure technical Q&A, project details, one-off operational instructions.

Output format (follow this XML exactly, no extra text):
<gate>
  <user_memory>true or false</user_memory>
</gate>

## Conversation
{{conversation}}
'''
          .trim();

  // ── §12.5 Extract ────────────────────────────────────────────────────────

  static final String extractZh =
      '''
从对话中提取用户画像的新信息。每条信息独立、简洁、完整。

四类画像：
- identity（身份）：姓名、性别、代词偏好、职业、公司、身边的人、能力背景
- workflow（工作方式）：做事流程、工具偏好、调试习惯
- voice（表达风格）：行文风格、句式节奏、用词习惯
- instruction（用户指令）：用户对助手的明确要求——回复风格、禁止项、交互偏好

规则：
- 只从用户说的话里提取
- 不提取助手的角色设定
- 不提取可以直接从对话记录或代码里查到的事实
- 每条一句话，独立自包含，用第三人称描述用户
- 不使用「这个」「刚才」等指回本次对话的词
- 「已有记忆」里已经出现过的信息不要重复提取

## 已有记忆
{{existingMemory}}

输出格式：
<extracted>
<item type="identity|workflow|voice|instruction">一句话描述</item>
</extracted>

如果没有值得提取的信息：
<extracted/>

## 对话
{{conversation}}
'''
          .trim();

  static final String extractEn =
      '''
Extract new information about the user from the conversation. Each item must be independent, concise and complete.

Four categories:
- identity: name, gender, pronoun preference, occupation, company, people around them, background
- workflow: how they work, tool preferences, debugging habits
- voice: writing style, sentence rhythm, word choice
- instruction: explicit requirements the user has for the assistant — reply style, prohibitions, interaction preferences

Rules:
- Extract only from what the user said
- Do not extract the assistant's persona
- Do not extract facts that can be looked up directly in the chat history or in code
- One sentence per item, self-contained, third person about the user
- Do not use words like "this" or "just now" that point back to the current conversation
- Do not re-extract anything already present in "Existing memory"

## Existing memory
{{existingMemory}}

Output format:
<extracted>
<item type="identity|workflow|voice|instruction">one sentence</item>
</extracted>

If there is nothing worth extracting:
<extracted/>

## Conversation
{{conversation}}
'''
          .trim();

  /// Appended under Extract rules when write scope is `toolDefault*`.
  static const String extractToolDefaultScopeRuleZh =
      '- 只对当前助手成立的信息，在 item 上加 scope="assistant"；对所有场景都成立的加 scope="global" 或省略';

  static const String extractToolDefaultScopeRuleEn =
      '- For information that only applies to the current assistant, add scope="assistant" on the item; for information that applies everywhere, add scope="global" or omit it';

  // ── §12.6 Smart Add (per-item) ───────────────────────────────────────────

  static final String smartAddZh =
      '''
你是记忆去重判断器。判断新信息与已有记忆的关系。

## 新信息
类型：{{type}}
内容：{{newInfo}}

## 相似的已有记忆（最多 5 条）
{{entriesText}}

判断：
- NEW：已有记忆中没有相关的，应新增
- MERGE：应合并到某条已有记忆，输出合并后的完整内容
- CONFLICT：与某条已有记忆矛盾（用户改变了偏好），归档旧的、写入新的
- SKIP：已有记忆中已包含此信息，无需操作

同时判断：上面列出的已有记忆中，哪些与新信息语义相关（即使不重复也不矛盾）？

只输出 JSON，不要解释：
{ "action": "NEW" | "MERGE" | "CONFLICT" | "SKIP", "targetId": "...", "mergedContent": "...", "relatedIds": ["mem_xxxxxxxx"] }
'''
          .trim();

  static final String smartAddEn =
      '''
You are a memory deduplication judge. Decide how the new information relates to existing memory.

## New information
Type: {{type}}
Content: {{newInfo}}

## Similar existing memories (up to 5)
{{entriesText}}

Decide:
- NEW: nothing related exists; create a new entry
- MERGE: merge into an existing entry; output the full merged content
- CONFLICT: contradicts an existing entry (the user changed a preference); archive the old one and write the new one
- SKIP: existing memory already contains this information; do nothing

Also decide: which of the listed existing memories are semantically related to the new information (even if not duplicate and not conflicting)?

Output JSON only, no explanation:
{ "action": "NEW" | "MERGE" | "CONFLICT" | "SKIP", "targetId": "...", "mergedContent": "...", "relatedIds": ["mem_xxxxxxxx"] }
'''
          .trim();

  // ── §12.6 Smart Add (batched) ────────────────────────────────────────────

  static final String smartAddBatchZh =
      '''
你是记忆去重判断器。判断每条新信息与已有记忆的关系。

## 新信息
{{itemsText}}

## 相似的已有记忆
{{entriesText}}

对每条新信息给出判断：
- NEW：已有记忆中没有相关的，应新增
- MERGE：应合并到某条已有记忆，输出合并后的完整内容
- CONFLICT：与某条已有记忆矛盾（用户改变了偏好），归档旧的、写入新的
- SKIP：已有记忆中已包含此信息，无需操作

同时对每条新信息判断：上面列出的已有记忆里哪些与它语义相关（即使不重复也不矛盾）？

只输出 JSON，不要解释：
{"results":[{"index":1,"action":"NEW","targetId":null,"mergedContent":null,"relatedIds":[]}]}
'''
          .trim();

  static final String smartAddBatchEn =
      '''
You are a memory deduplication judge. Decide how each piece of new information relates to existing memory.

## New information
{{itemsText}}

## Similar existing memories
{{entriesText}}

For each piece of new information, decide:
- NEW: nothing related exists; create a new entry
- MERGE: merge into an existing entry; output the full merged content
- CONFLICT: contradicts an existing entry (the user changed a preference); archive the old one and write the new one
- SKIP: existing memory already contains this information; do nothing

Also, for each piece of new information, decide which of the listed existing memories are semantically related to it (even if not duplicate and not conflicting).

Output JSON only, no explanation:
{"results":[{"index":1,"action":"NEW","targetId":null,"mergedContent":null,"relatedIds":[]}]}
'''
          .trim();

  // ── §12.7 Profile Distiller ──────────────────────────────────────────────

  static final String profileDistillZh =
      '''
从用户的身份类记忆中提炼稳定的画像字段。

## 当前画像
{{profileBlock}}

## 身份类记忆
{{identityEntries}}

可用字段：preferred_name（用户希望被怎么称呼）、gender、pronouns、preferred_language、timezone、occupation、location

规则：
- 记忆中没有明确依据的字段不要输出
- 当前画像已经有值、且记忆没有推翻它的字段不要输出
- preferred_name 只在用户明确表达过希望被怎么称呼时才输出；不要使用记忆中出现的其他人的名字
- 不确定就不输出

只输出 JSON，不要解释：
{"fields":[{"key":"preferred_name","value":"..."}]}
'''
          .trim();

  static final String profileDistillEn =
      '''
Distill stable profile fields from the user's identity memories.

## Current profile
{{profileBlock}}

## Identity memories
{{identityEntries}}

Available fields: preferred_name (how the user wants to be addressed), gender, pronouns, preferred_language, timezone, occupation, location

Rules:
- Do not output a field without clear evidence in the memories
- Do not output a field that already has a value in the current profile unless the memories overturn it
- Only output preferred_name when the user has explicitly said how they want to be addressed; never use the name of another person that appears in memory
- If uncertain, do not output

Output JSON only, no explanation:
{"fields":[{"key":"preferred_name","value":"..."}]}
'''
          .trim();

  // ── Legacy memory migration ──────────────────────────────────────────────

  static final String migrateZh =
      '''
你正在把旧版长期记忆迁入带类型的记忆系统。

对每一条输入，返回一条 id 相同的输出。保留全部事实、偏好、否定、限定和不确定表述。保持原文语言。只做让记忆简洁、自包含、脱离对话上下文也能看懂的改写。适合时用第三人称描述用户。

只选一个类型：
- identity：稳定事实、偏好、背景、人际关系、兴趣或个人上下文
- workflow：用户做事、决策、规划或使用工具的惯常方式
- voice：偏好的语气、措辞、语言、格式或沟通风格
- instruction：对助手应如何表现或回复的持久规则

不要编造、翻译、合并、拆分、省略、去重、解释或添加建议。

只返回这种形状的 JSON 数组：
[{"id":1,"type":"identity","content":"..."}]

输入：
{{items}}
'''
          .trim();

  static final String migrateEn =
      '''
You are migrating legacy long-term memories into a typed memory system.

For every input item, return exactly one output item with the same integer id. Preserve every fact, preference, negation, qualification, and uncertainty. Keep the original language. Rewrite only enough to make the memory concise, self-contained, and understandable without conversation context. When appropriate, phrase it as a third-person statement about the user.

Choose exactly one type:
- identity: stable facts, preferences, background, relationships, interests, or personal context
- workflow: recurring ways the user works, decides, plans, or uses tools
- voice: preferred tone, wording, language, formatting, or communication style
- instruction: durable rules for how an assistant should behave or respond

Do not invent, translate, merge, split, omit, deduplicate, explain, or add advice.

Return only a JSON array in this exact shape:
[{"id":1,"type":"identity","content":"..."}]

Input:
{{items}}
'''
          .trim();

  static final String migratePreserveZh =
      '''
你正在把旧版长期记忆分类到带类型的记忆系统。内容由系统原样保留，你只负责分类。

对每一条输入，返回一条 id 相同的输出。只选一个类型：
- identity：稳定事实、偏好、背景、人际关系、兴趣或个人上下文
- workflow：用户做事、决策、规划或使用工具的惯常方式
- voice：偏好的语气、措辞、语言、格式或沟通风格
- instruction：对助手应如何表现或回复的持久规则

不要改写、翻译、编造、合并、拆分或省略。不要输出 content。

只返回这种形状的 JSON 数组：
[{"id":1,"type":"identity"}]

输入：
{{items}}
'''
          .trim();

  static final String migratePreserveEn =
      '''
You are classifying legacy long-term memories into a typed memory system. The system will keep each memory's original wording. You only assign a type.

For every input item, return exactly one output item with the same integer id. Choose exactly one type:
- identity: stable facts, preferences, background, relationships, interests, or personal context
- workflow: recurring ways the user works, decides, plans, or uses tools
- voice: preferred tone, wording, language, formatting, or communication style
- instruction: durable rules for how an assistant should behave or respond

Do not rewrite, translate, invent, merge, split, or omit items. Do not output content.

Return only a JSON array in this exact shape:
[{"id":1,"type":"identity"}]

Input:
{{items}}
'''
          .trim();

  // ── §7.5 injection intros ────────────────────────────────────────────────

  static const String introFullZh = '以下内容由系统提供，不是用户本轮发送的内容。';
  static const String introFullEn =
      'The following context is provided by the system. It is not what the user said in this turn.';
  static const String introUpdateZh = '以下是本次对话开始后发生的记忆更新，由系统提供。';
  static const String introUpdateEn =
      'The following memory changes happened after this conversation started, provided by the system.';

  // ── §7.2 moreHint ────────────────────────────────────────────────────────

  static const String moreHintZh = '[更多内容请使用 memory_search_profile 查询]';
  static const String moreHintEn =
      '[More entries exist. Use memory_search_profile to look them up.]';

  // ── §9.1 / §9.3 time helpers ─────────────────────────────────────────────

  static const List<String> _weekdayAbbrev = [
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];

  /// Wraps [timestamp] as `<current_time>EEE yyyy-MM-dd HH:mm:ss</current_time>`
  /// in the local timezone, without a UTC offset (§9.1).
  ///
  /// Four-digit year avoids `yy-MM-dd` / `dd-MM-yy` ambiguity (e.g. 22–26).
  static String formatCurrentTimeTag(DateTime timestamp) {
    final local = timestamp.isUtc ? timestamp.toLocal() : timestamp;
    final eee = _weekdayAbbrev[local.weekday - 1];
    final yyyy = local.year.toString();
    final mm = local.month.toString().padLeft(2, '0');
    final dd = local.day.toString().padLeft(2, '0');
    final hh = local.hour.toString().padLeft(2, '0');
    final min = local.minute.toString().padLeft(2, '0');
    final ss = local.second.toString().padLeft(2, '0');
    return '<current_time>$eee $yyyy-$mm-$dd $hh:$min:$ss</current_time>';
  }

  /// Returns which of `{cur_date}`, `{cur_time}`, `{cur_datetime}` occur in
  /// [systemPrompt], in that fixed order. `{timezone}` etc. are ignored (§9.3).
  static List<String> detectTimeVariablesInSystemPrompt(String systemPrompt) {
    const candidates = ['{cur_date}', '{cur_time}', '{cur_datetime}'];
    return [
      for (final token in candidates)
        if (systemPrompt.contains(token)) token,
    ];
  }

  static String rulesFor(MemoryPromptLang lang) =>
      lang == MemoryPromptLang.zh ? rulesZh : rulesEn;

  static String rulesPastConversationRecallFor(MemoryPromptLang lang) =>
      lang == MemoryPromptLang.zh
      ? rulesPastConversationRecallZh
      : rulesPastConversationRecallEn;

  static String gateFor(MemoryPromptLang lang) =>
      lang == MemoryPromptLang.zh ? gateZh : gateEn;

  static String extractFor(MemoryPromptLang lang) =>
      lang == MemoryPromptLang.zh ? extractZh : extractEn;

  static String extractToolDefaultScopeRuleFor(MemoryPromptLang lang) =>
      lang == MemoryPromptLang.zh
      ? extractToolDefaultScopeRuleZh
      : extractToolDefaultScopeRuleEn;

  static String smartAddFor(MemoryPromptLang lang) =>
      lang == MemoryPromptLang.zh ? smartAddZh : smartAddEn;

  static String smartAddBatchFor(MemoryPromptLang lang) =>
      lang == MemoryPromptLang.zh ? smartAddBatchZh : smartAddBatchEn;

  static String profileDistillFor(MemoryPromptLang lang) =>
      lang == MemoryPromptLang.zh ? profileDistillZh : profileDistillEn;

  static String migrateFor(MemoryPromptLang lang) =>
      lang == MemoryPromptLang.zh ? migrateZh : migrateEn;

  static String migratePreserveFor(MemoryPromptLang lang) =>
      lang == MemoryPromptLang.zh ? migratePreserveZh : migratePreserveEn;

  static String introFullFor(MemoryPromptLang lang) =>
      lang == MemoryPromptLang.zh ? introFullZh : introFullEn;

  static String introUpdateFor(MemoryPromptLang lang) =>
      lang == MemoryPromptLang.zh ? introUpdateZh : introUpdateEn;

  static String moreHintFor(MemoryPromptLang lang) =>
      lang == MemoryPromptLang.zh ? moreHintZh : moreHintEn;
}
