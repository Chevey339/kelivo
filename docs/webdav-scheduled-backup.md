# Scheduled WebDAV backups

Open **Settings → Backup → Scheduled WebDAV backup** after saving and testing
the WebDAV server settings. Automatic backups are disabled by default.

- Choose an interval of 1, 6, 12, 24, 72, or 168 hours.
- Choose whether to wait for Wi-Fi or a wired connection.
- Use **Run now** to test the saved server settings and backup scope immediately.
- Check the most recent successful backup, next approximate run, and execution
  status in the same section.

The first scheduled run is due one full interval after enabling the feature.
Successful runs start the next interval. Failed uploads retry with a delay;
offline or busy devices wait until the execution conditions are available.
Each upload uses the existing ZIP backup format and the saved backup categories.
The schedule is device-local: importing a backup does not enable unattended
uploads on another device.

Encrypted backups require interactive password confirmation. When backup
encryption is enabled, scheduled runs and **Run now** in the scheduled-backup
section stop with a password-confirmation message. Use the regular manual
WebDAV backup action to enter the encryption password, or explicitly turn off
backup encryption before using scheduled backups. The password stays in the
interactive backup session; the scheduler does not store it or fall back to an
unencrypted upload.

## Android background execution

Android uses WorkManager, alongside checks in the running app. WorkManager can
start a backup after the activity closes or the process exits. Execution times
are approximate: battery saving, network availability, and Android background
limits can postpone a run. Force-stopping the application prevents scheduled
work until the application is opened again.

A retained application engine handles the job when it already owns the database.
A cold background worker acquires the existing business-data lease and refuses
to open data awaiting restore or migration. Opening the app takes priority over
background archive preparation. Manual backup and restore operations cancel and
wait for automatic work before accessing the data.

On other platforms, scheduled checks run while the application is active. The
settings screen describes the applicable background behavior.

## Manual verification

1. Save a test WebDAV directory and use the existing connection test.
2. Select the desired backup categories and use **Run now**.
3. Confirm that the ZIP appears on the server and that the success time updates.
4. Enable a one-hour interval and leave the app in the background. Allow extra
   time for Android scheduling and check the recorded result after returning.
5. Test network restrictions and a deliberately incorrect password, then restore
   the correct settings and confirm that another manual run succeeds.
6. Disable the schedule and verify that no further scheduled upload occurs.
