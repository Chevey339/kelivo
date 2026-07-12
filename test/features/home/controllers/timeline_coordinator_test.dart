import 'dart:async';

import 'package:Kelivo/core/database/message_graph_projector.dart';
import 'package:Kelivo/core/models/chat_message.dart';
import 'package:Kelivo/core/services/chat/chat_service.dart';
import 'package:Kelivo/features/home/controllers/timeline_coordinator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  LoadedTimelineSlot slot(int index, {bool isStreaming = false}) {
    final id = 'revision-$index';
    final timestamp = DateTime(2026, 7, 11);
    return LoadedTimelineSlot(
      identity: ActiveTimelineSlot(
        slotId: 'slot-$index',
        revisionId: id,
        parentRevisionId: index == 0 ? null : 'revision-${index - 1}',
        role: index.isEven ? 'user' : 'assistant',
        createdAt: timestamp,
        updatedAt: timestamp,
        finalizedAt: timestamp,
        versionCount: index == 2 ? 500 : 1,
        logicalIndex: index,
      ),
      message: ChatMessage(
        id: id,
        role: index.isEven ? 'user' : 'assistant',
        content: '$index',
        conversationId: 'conversation',
        isStreaming: isStreaming,
      ),
    );
  }

  LoadedTimelinePage page(
    List<int> indices, {
    required bool before,
    required bool after,
    int stateRevision = 0,
  }) => LoadedTimelinePage(
    conversationId: 'conversation',
    stateRevision: stateRevision,
    contextStartRevisionId: null,
    slots: indices.map(slot).toList(),
    hasMoreBefore: before,
    hasMoreAfter: after,
    totalSlotCount: 6,
  );

  test(
    'coordinator pages by revision cursor and keeps one row per slot',
    () async {
      final calls = <({String? before, String? after})>[];
      final coordinator = TimelineCoordinator(
        loadPage:
            ({
              required conversationId,
              beforeRevisionId,
              afterRevisionId,
              fromStart,
              required limit,
            }) async {
              calls.add((before: beforeRevisionId, after: afterRevisionId));
              if (beforeRevisionId != null) {
                return page([0, 1], before: false, after: true);
              }
              if (afterRevisionId != null) {
                return page([4, 5], before: true, after: false);
              }
              return page([2, 3], before: true, after: true);
            },
      );

      await coordinator.open('conversation', limit: 2);
      expect(coordinator.slots.map((entry) => entry.identity.slotId), [
        'slot-2',
        'slot-3',
      ]);
      expect(coordinator.slots.first.identity.versionCount, 500);

      expect(await coordinator.loadBefore(limit: 2), isTrue);
      expect(await coordinator.loadAfter(limit: 2), isTrue);
      expect(coordinator.slots.map((entry) => entry.identity.revisionId), [
        'revision-0',
        'revision-1',
        'revision-2',
        'revision-3',
        'revision-4',
        'revision-5',
      ]);
      expect(calls, [
        (before: null, after: null),
        (before: 'revision-2', after: null),
        (before: null, after: 'revision-3'),
      ]);
    },
  );

  test('row and decoded-byte budgets evict the opposite edge', () async {
    final retained = <String>[];
    final coordinator = TimelineCoordinator(
      budget: const TimelineWindowBudget(maxSlots: 3, maxDecodedBytes: 600),
      retainWindow: (_, ids) {
        retained
          ..clear()
          ..addAll(ids);
      },
      loadPage:
          ({
            required conversationId,
            beforeRevisionId,
            afterRevisionId,
            fromStart,
            required limit,
          }) async => page([0, 1, 2, 3], before: true, after: false),
    );

    await coordinator.open('conversation');

    expect(coordinator.slots, hasLength(3));
    expect(coordinator.slots.map((slot) => slot.identity.revisionId), [
      'revision-1',
      'revision-2',
      'revision-3',
    ]);
    expect(coordinator.decodedBytes, lessThanOrEqualTo(600));
    expect(retained, ['revision-1', 'revision-2', 'revision-3']);
    expect(coordinator.hasMoreBefore, isTrue);
  });

  test('late page from a previous conversation is discarded', () async {
    final first = Completer<LoadedTimelinePage?>();
    final coordinator = TimelineCoordinator(
      loadPage:
          ({
            required conversationId,
            beforeRevisionId,
            afterRevisionId,
            fromStart,
            required limit,
          }) async {
            if (conversationId == 'first') return first.future;
            return LoadedTimelinePage(
              conversationId: 'second',
              stateRevision: 0,
              contextStartRevisionId: null,
              slots: [slot(5)],
              hasMoreBefore: false,
              hasMoreAfter: false,
              totalSlotCount: 1,
            );
          },
    );

    final staleOpen = coordinator.open('first');
    await coordinator.open('second');
    first.complete(page([0, 1], before: false, after: false));
    await staleOpen;

    expect(coordinator.conversationId, 'second');
    expect(coordinator.slots.single.identity.revisionId, 'revision-5');
  });

  test(
    'same-conversation open keeps the visible window while refreshing',
    () async {
      final refresh = Completer<LoadedTimelinePage?>();
      var calls = 0;
      final coordinator = TimelineCoordinator(
        loadPage:
            ({
              required conversationId,
              beforeRevisionId,
              afterRevisionId,
              fromStart,
              required limit,
            }) async {
              calls++;
              if (calls == 1) {
                return page([2, 3], before: true, after: false);
              }
              return refresh.future;
            },
      );
      await coordinator.open('conversation');
      final visibleSlots = coordinator.slots.toList();
      final visibleRevision = coordinator.windowRevision;

      final refreshing = coordinator.open('conversation');
      await Future<void>.delayed(Duration.zero);

      expect(coordinator.slots, visibleSlots);
      expect(coordinator.windowRevision, visibleRevision);

      refresh.complete(page([3, 4], before: true, after: false));
      await refreshing;
      expect(coordinator.slots.map((entry) => entry.identity.revisionId), [
        'revision-3',
        'revision-4',
      ]);
      expect(coordinator.windowRevision, visibleRevision + 1);
    },
  );

  test(
    'openAround replaces the window around a stable revision cursor',
    () async {
      String? requestedRevisionId;
      final coordinator = TimelineCoordinator(
        loadPage:
            ({
              required conversationId,
              beforeRevisionId,
              afterRevisionId,
              fromStart,
              required limit,
            }) async => page([4, 5], before: true, after: false),
        loadAroundPage:
            ({
              required conversationId,
              required targetRevisionId,
              required limit,
            }) async {
              requestedRevisionId = targetRevisionId;
              return page([1, 2, 3], before: true, after: true);
            },
      );
      await coordinator.open('conversation');

      expect(await coordinator.openAround('revision-2', limit: 3), isTrue);

      expect(requestedRevisionId, 'revision-2');
      expect(coordinator.slots.map((entry) => entry.identity.revisionId), [
        'revision-1',
        'revision-2',
        'revision-3',
      ]);
      expect(coordinator.viewportMode, TimelineViewportMode.programmaticJump);
      expect(coordinator.programmaticTargetSlotId, 'slot-2');
    },
  );

  test('slot ID and localDy resolve layout drift within one logical pixel', () {
    final coordinator = TimelineCoordinator(
      loadPage:
          ({
            required conversationId,
            beforeRevisionId,
            afterRevisionId,
            fromStart,
            required limit,
          }) async => null,
    );
    final anchor = coordinator.captureVisualAnchor(
      geometries: const [
        TimelineSlotGeometry(slotId: 'partial', top: 80, bottom: 130),
        TimelineSlotGeometry(slotId: 'stable', top: 130, bottom: 220),
      ],
      viewportTop: 100,
      viewportBottom: 500,
    );
    expect(anchor?.slotId, 'stable');
    expect(anchor?.localDy, 30);

    expect(
      coordinator.resolveVisualAnchorCorrection(
        geometries: const [
          TimelineSlotGeometry(slotId: 'stable', top: 267.25, bottom: 357.25),
        ],
        viewportTop: 100,
      ),
      137.25,
    );
    expect(
      coordinator.resolveVisualAnchorCorrection(
        geometries: const [
          TimelineSlotGeometry(slotId: 'stable', top: 130.75, bottom: 220.75),
        ],
        viewportTop: 100,
      ),
      0,
    );
  });

  test('viewport intent preserves history reading while content streams', () {
    final coordinator = TimelineCoordinator(
      loadPage:
          ({
            required conversationId,
            beforeRevisionId,
            afterRevisionId,
            fromStart,
            required limit,
          }) async => null,
    );

    expect(coordinator.viewportMode, TimelineViewportMode.followingTail);
    coordinator.userAnchored();
    coordinator.noteContentChanged(isGenerating: true);
    expect(coordinator.viewportMode, TimelineViewportMode.userAnchored);
    expect(coordinator.showJumpToLatest, isTrue);
    expect(coordinator.isGenerating, isTrue);

    coordinator.followTail();
    expect(coordinator.viewportMode, TimelineViewportMode.followingTail);
    expect(coordinator.hasUnreadContent, isFalse);
  });

  test('programmatic jump becomes an anchored viewport after placement', () {
    final coordinator = TimelineCoordinator(
      loadPage:
          ({
            required conversationId,
            beforeRevisionId,
            afterRevisionId,
            fromStart,
            required limit,
          }) async => null,
    );

    coordinator.programmaticJump('new-user-slot');
    coordinator.noteContentChanged(isGenerating: true);
    expect(coordinator.viewportMode, TimelineViewportMode.programmaticJump);
    expect(coordinator.programmaticTargetSlotId, 'new-user-slot');
    expect(coordinator.hasUnreadContent, isFalse);

    coordinator.completeProgrammaticJump();
    expect(coordinator.viewportMode, TimelineViewportMode.userAnchored);
    expect(coordinator.programmaticTargetSlotId, isNull);
    coordinator.noteContentChanged(isGenerating: true);
    expect(coordinator.showJumpToLatest, isTrue);
  });

  test('loaded streaming slot keeps generation layout state active', () async {
    var isStreaming = true;
    final coordinator = TimelineCoordinator(
      loadPage:
          ({
            required conversationId,
            beforeRevisionId,
            afterRevisionId,
            fromStart,
            required limit,
          }) async => LoadedTimelinePage(
            conversationId: conversationId,
            stateRevision: isStreaming ? 1 : 2,
            contextStartRevisionId: null,
            slots: [
              slot(0),
              slot(1, isStreaming: isStreaming),
            ],
            hasMoreBefore: false,
            hasMoreAfter: false,
            totalSlotCount: 2,
          ),
    );

    await coordinator.open('conversation');
    expect(coordinator.isGenerating, isTrue);

    isStreaming = false;
    await coordinator.open('conversation');
    expect(coordinator.isGenerating, isFalse);
  });

  test('paging loading state restores the previous viewport intent', () async {
    final completer = Completer<LoadedTimelinePage?>();
    final coordinator = TimelineCoordinator(
      loadPage:
          ({
            required conversationId,
            beforeRevisionId,
            afterRevisionId,
            fromStart,
            required limit,
          }) async {
            if (beforeRevisionId != null) return completer.future;
            return page([2, 3], before: true, after: false);
          },
    );
    await coordinator.open('conversation');
    coordinator.userAnchored();

    final loading = coordinator.loadBefore();
    expect(coordinator.viewportMode, TimelineViewportMode.loading);
    completer.complete(page([0, 1], before: false, after: true));
    await loading;
    expect(coordinator.viewportMode, TimelineViewportMode.userAnchored);
  });

  test('paging rebuilds the window when the graph revision changes', () async {
    var pageCalls = 0;
    final aroundTargets = <String>[];
    final coordinator = TimelineCoordinator(
      loadPage:
          ({
            required conversationId,
            beforeRevisionId,
            afterRevisionId,
            fromStart,
            required limit,
          }) async {
            pageCalls++;
            return switch (pageCalls) {
              1 => page([2, 3], before: true, after: false),
              2 => page([0, 1], before: false, after: true, stateRevision: 1),
              3 => page([1, 2], before: false, after: true, stateRevision: 1),
              _ => throw StateError('unexpected page request'),
            };
          },
      loadAroundPage:
          ({
            required conversationId,
            required targetRevisionId,
            required limit,
          }) async {
            aroundTargets.add(targetRevisionId);
            return page([3, 4], before: true, after: false, stateRevision: 1);
          },
    );
    await coordinator.open('conversation');
    coordinator.captureVisualAnchor(
      geometries: const [
        TimelineSlotGeometry(slotId: 'slot-3', top: 120, bottom: 180),
      ],
      viewportTop: 100,
      viewportBottom: 500,
    );

    expect(await coordinator.loadBefore(), isTrue);
    expect(pageCalls, 2);
    expect(aroundTargets, ['revision-3']);
    expect(coordinator.slots.map((entry) => entry.identity.revisionId), [
      'revision-3',
      'revision-4',
    ]);
    expect(coordinator.visualAnchor?.slotId, 'slot-3');
    expect(
      coordinator.resolveVisualAnchorCorrection(
        geometries: const [
          TimelineSlotGeometry(slotId: 'slot-3', top: 120, bottom: 180),
        ],
        viewportTop: 100,
      ),
      0,
    );

    expect(await coordinator.loadBefore(), isTrue);
    expect(pageCalls, 3);
    expect(coordinator.slots.map((entry) => entry.identity.revisionId), [
      'revision-1',
      'revision-2',
      'revision-3',
      'revision-4',
    ]);
  });
}
