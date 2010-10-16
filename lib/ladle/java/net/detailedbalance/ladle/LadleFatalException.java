package net.detailedbalance.ladle;

/**
 * @author Rhett Sutphin
 */
public class LadleFatalException extends RuntimeException {
    public LadleFatalException(String message) {
        super(message);
    }

    public LadleFatalException(String msg, Throwable cause) {
        super(msg, cause);
    }
}
