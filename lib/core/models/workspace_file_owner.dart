/// The workspace or external mount from which a writable preview was opened.
/// A host path or the active chat alone does not grant edit access.
enum WorkspaceFileOwnerKind { workspace, mount }

typedef WorkspaceFileOwner = ({WorkspaceFileOwnerKind kind, String id});
