package net.detailedbalance.ladle;

import org.apache.commons.cli.CommandLine;
import org.apache.commons.cli.CommandLineParser;
import org.apache.commons.cli.GnuParser;
import org.apache.commons.cli.OptionBuilder;
import org.apache.commons.cli.Options;
import org.apache.commons.cli.ParseException;
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
 * tightly bound to the ruby controller code in <code>lib/ladle/server.rb</code>.  There is no
 * validation for form at this level -- it's all done in ruby.
 *
 * @author Rhett Sutphin
 */
public class Main {
    public static void main(String[] args) {
        configureLog4j();

        CommandLine commandLine = parseArgs(args);

        try {
            if (commandLine.hasOption('F')) {
                behaveBadly(commandLine.getOptionValue('F'));
            }

            final Server s = new Server(
                new Integer(commandLine.getOptionValue("p")),
                "dc=example,dc=org",
                new File("lib/ladle/default.ldif"),
                new File("/tmp"));

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

    @SuppressWarnings({ "InfiniteLoopStatement" })
    private static void behaveBadly(String desiredFailureType) throws InterruptedException {
        if ("before_start".equals(desiredFailureType)) {
            reportError("Expected failure for testing");
            System.exit(207);
        } else if ("hang".equals(desiredFailureType)) {
            while (true) { Thread.sleep(1000); }
        }
    }

    @SuppressWarnings({"AccessStaticViaInstance"})
    private static CommandLine parseArgs(String[] args) {
        Options options = new Options()
            .addOption(OptionBuilder.
                withLongOpt("fail").hasArg().
                withDescription("Force a failure (for testing)").
                create('F'))
            .addOption(OptionBuilder.
                withLongOpt("port").hasArg().isRequired().
                withDescription("Specify port to use").
                create('p'));
        CommandLineParser parser = new GnuParser();

        try {
            return parser.parse(options, args);
        } catch (ParseException e) {
            reportError(e);
            System.exit(18);
            return null; // unreachable
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
        reportError(e.getMessage());
        e.printStackTrace(System.err);
    }

    private static void reportError(String message) {
        System.out.println("FATAL: " + message);
    }
}
