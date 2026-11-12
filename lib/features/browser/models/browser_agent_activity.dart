/// Permission to use the browser is separate from a running model/tool action.
enum BrowserAgentActivity { idle, running, paused }

enum BrowserAgentPauseReason { user, timeout }

typedef BrowserAgentPause = ({BrowserAgentPauseReason reason, String? tabId});
