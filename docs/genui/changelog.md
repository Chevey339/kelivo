# IntelligentUI release notes

Native interface inputs and limited view settings are included with chat
backups. Importing a new backup into the frozen v3 reader preserves conversations,
messages, selected revisions and the original interface source, while discarding
the additional GenUI state and search indexes. A later import of that v3 export
can reconstruct default interfaces but cannot recover the discarded overrides.
The original v5 backup retains those overrides and can be restored again.

This compatibility contract applies to backup import. It does not promise that
an older installed application can open a newer live database in place. Actual
manual compatibility evidence is recorded separately in the implementation log;
the script's existence alone is not a passing result.
