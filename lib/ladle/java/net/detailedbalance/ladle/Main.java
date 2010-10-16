package net.detailedbalance.ladle;

import org.apache.log4j.BasicConfigurator;
import org.apache.log4j.ConsoleAppender;
import org.apache.log4j.Level;
import org.apache.log4j.PatternLayout;

import java.io.BufferedReader;
import java.io.File;
import java.io.IOException;
import java.io.InputStreamReader;
import java.io.PrintWriter;

/**
 * The executable front-end to {@link Server}.  Uses stdin/stdout as a control channel, with
 * tracing info printed to stderr. The arguments expected and the control channel contents are
 * tightly bound to the ruby controller code in <code>lib/ladle/server.rb</code>.
 *
 * @author Rhett Sutphin
 */
public class Main {
    public static void main(String[] args) {
        configureLog4j();

        try {
            final Server s = new Server(3897, "dc=example,dc=org",
                new File("lib/ladle/default.ldif"), new File("/tmp"));

            Runtime.getRuntime().addShutdownHook(new Thread(new Runnable() {
                public void run() {
                    s.stop();
                    System.out.println("STOPPED");
                }
            }));

            s.start();
            System.out.println("STARTED");
        } catch (LadleFatalException lfe) {
            reportError(lfe);
            System.exit(1);
        } catch (Exception e) {
            reportError(e);
            System.exit(2);
        }

        BufferedReader in = new BufferedReader(new InputStreamReader(System.in));
        String line;
        try {
            //noinspection LoopStatementThatDoesntLoop
            while ((line = in.readLine()) != null) {
                if ("STOP".equals(line)) {
                    System.exit(0); // shutdown hook will handle stopping everything
                } else {
                    System.out.println("FATAL: unknown control message \"" + line + '"');
                    System.exit(9);
                }
            }
        } catch (IOException e) {
            reportError(e);
            System.exit(3);
        }
    }

    private static void configureLog4j() {
        ConsoleAppender appender = new ConsoleAppender();
        appender.setWriter(new PrintWriter(System.err));
        appender.setLayout(new PatternLayout("%p: %m%n"));
        appender.setThreshold(Level.INFO);
        BasicConfigurator.configure(appender);
    }

    private static void reportError(Exception e) {
        System.out.println("FATAL: " + e.getMessage());
        e.printStackTrace(System.err);
    }
}
