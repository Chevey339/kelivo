package com.psyche.kelivo.workspace;

import android.os.Process;
import java.io.BufferedReader;
import java.io.File;
import java.io.InputStreamReader;
import java.nio.file.Files;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;

/** Device crash fixture, compiled with the app's workspace classes and Kotlin
 * stdlib, then dexed for app_process. Run `launch DIR ID [pty]`, kill only the
 * printed app PID, and run `recover DIR`. The guest intentionally stays alive
 * after stdin EOF. The driver must verify both recorded PIDs disappear and
 * repeat with another still-live owner to check that it is preserved. */
public final class AndroidWorkspaceProcessTest {
    private static java.lang.Process child;

    private static WorkspaceProcessOwner owner() throws Exception {
        return new WorkspaceProcessOwner("com.psyche.kelivo.process-test",
            new File("/proc"), Process.myUid(), Process.myPid(), (pid, stillOwned) -> {
                ExecRunnerKt.requestProotExit(pid, stillOwned);
                return kotlin.Unit.INSTANCE;
            }, 5000L);
    }

    public static void main(String[] args) throws Exception {
        WorkspaceProcessOwner owner = owner();
        owner.recoverOrphans();
        if (args[0].equals("recover")) {
            System.out.println("recovered");
            return;
        }
        String directory = args[1];
        String id = args[2];
        String workDirectory = args.length > 4 ? args[4] : directory;
        Map<String, String> env = new java.util.HashMap<>(owner.environment("mcp-" + id));
        env.put("PROOT_LOADER", directory + "/libproot_loader.so");
        env.put("PROOT_TMP_DIR", workDirectory);
        env.put("LD_LIBRARY_PATH", directory + ":" + workDirectory);
        ProcessBuilder builder = new ProcessBuilder(ExecRunnerKt.workspaceExecArgv(java.util.Arrays.asList(
            directory + "/libproot_exec.so", "--kill-on-exit", "-r", "/", "-w", "/",
            "/system/bin/sh", "-c",
            "echo $$ > " + workDirectory + "/" + id + ".guest; echo ready; " +
            "while IFS= read -r line; do printf 'reply:%s\\n' \"$line\"; done; " +
            "exec /system/bin/sleep 600"), "/system/bin/sh"));
        builder.environment().putAll(env);
        child = builder.start();
        BufferedReader output = new BufferedReader(new InputStreamReader(child.getInputStream()));
        if (!"ready".equals(output.readLine())) throw new AssertionError("guest did not start");
        child.getOutputStream().write("ping\n".getBytes("UTF-8"));
        child.getOutputStream().flush();
        if (!"reply:ping".equals(output.readLine())) throw new AssertionError("stdio exchange failed");
        long pid = ExecRunnerKt.processPid(child);
        String report = Process.myPid() + " " + pid;
        if (args.length > 3 && args[3].equals("pty")) {
            env.putAll(owner.environment("pty-" + id));
            List<String> hostEnv = new ArrayList<>();
            for (Map.Entry<String, String> item : env.entrySet()) hostEnv.add(item.getKey() + "=" + item.getValue());
            int[] ptyPid = new int[1];
            int fd = PtyJni.createSubprocess(directory + "/libproot_exec.so", workDirectory,
                new String[]{"--kill-on-exit", "-r", "/", "-w", "/", "/system/bin/sleep", "600"},
                hostEnv.toArray(new String[0]), ptyPid, 24, 80);
            if (fd < 0) throw new AssertionError("PTY failed");
            // Wait for exec to complete before examining its inherited FDs.
            if (!ProotShutdownKt.awaitProotSignalHandler(new File("/proc/" + ptyPid[0]), 5000, () -> true)) {
                throw new AssertionError("PTY did not start");
            }
            String stdin = Files.readSymbolicLink(new File("/proc/" + pid + "/fd/0").toPath()).toString();
            File[] descriptors = new File("/proc/" + ptyPid[0] + "/fd").listFiles();
            if (descriptors == null) throw new AssertionError("cannot inspect PTY descriptors");
            for (File descriptor : descriptors) {
                if (stdin.equals(Files.readSymbolicLink(descriptor.toPath()).toString())) {
                    throw new AssertionError("PTY inherited MCP stdin: " + descriptor);
                }
            }
            report += " " + ptyPid[0];
        }
        Files.write(new File(workDirectory, id + ".pids").toPath(), report.getBytes("UTF-8"));
        System.out.println("ready " + report);
        System.out.flush();
        Thread.sleep(600_000);
    }
}
