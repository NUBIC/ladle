package net.detailedbalance.ladle;

import org.apache.commons.io.FileUtils;
import org.apache.directory.server.configuration.MutableServerStartupConfiguration;
import org.apache.directory.server.core.configuration.Configuration;
import org.apache.directory.server.core.configuration.MutablePartitionConfiguration;
import org.apache.directory.server.core.configuration.ShutdownConfiguration;
import org.apache.directory.server.core.schema.bootstrap.BootstrapSchema;
import org.apache.log4j.Logger;

import javax.naming.Context;
import javax.naming.NamingException;
import javax.naming.directory.Attribute;
import javax.naming.directory.Attributes;
import javax.naming.directory.BasicAttribute;
import javax.naming.directory.BasicAttributes;
import javax.naming.directory.InitialDirContext;
import java.io.File;
import java.io.IOException;
import java.util.Collection;
import java.util.Collections;
import java.util.HashSet;
import java.util.Hashtable;
import java.util.Set;
import java.util.UUID;

/**
 * The class that creates and controls an embedded ApacheDS instance.  This runner is not designed
 * for thread-safety or even to be used in the same JVM as anything else -- it's intended to be run
 * in its own process to provide LDAP access over TCP.
 * <p>
 * The idea of using ApacheDS for this was from Spring Security's LDAP test support.  The details
 * are from the ApacheDS embedding and unit testing documentation.
 */
public class Server {
    private final Logger log = Logger.getLogger(getClass());

    private final int port;
    private final String domainComponent;
    private final boolean allowAnonymous;
    private final File tempDir;
    private final File ldifDir;
    private boolean running = false;
    private Collection<Class<?>> customSchemas = Collections.emptyList();

    public Server(
        int port, String domainComponent, File ldifFile, File tempDirBase, boolean allowAnonymous
    ) {
        this.port = port;
        this.domainComponent = domainComponent;
        this.allowAnonymous = allowAnonymous;
        this.tempDir = createTempDir(tempDirBase);
        this.ldifDir = prepareLdif(ldifFile);
    }

    ////// SETUP

    private File createTempDir(File tempDirBase) {
        File temp = new File(tempDirBase, "ladle-server-" + UUID.randomUUID());
        
        if (temp.mkdir()) {
            return temp;
        } else {
            throw new LadleFatalException("Could not create temporary directory " + temp);
        }
    }

    private static Hashtable<String, String> baseEnvironment() {
        Hashtable<String, String> env = new Hashtable<String, String>();
        env.put(Context.PROVIDER_URL, "");
        env.put(Context.INITIAL_CONTEXT_FACTORY,
            "org.apache.directory.server.jndi.ServerContextFactory");

        // these values are apparently hardcoded in ApacheDS
        env.put(Context.SECURITY_PRINCIPAL, "uid=admin,ou=system");
        env.put(Context.SECURITY_CREDENTIALS, "secret");
        env.put(Context.SECURITY_AUTHENTICATION, "simple");

        return env;
    }

    private File prepareLdif(File ldifFile) {
        File dir = new File(tempDir, "ldif");
        if (!dir.mkdir()) {
            throw new LadleFatalException("Could not create LDIF directory " + dir);
        }

        try {
            FileUtils.copyFileToDirectory(ldifFile, dir);
        } catch (IOException e) {
            throw new LadleFatalException("Copying " + ldifFile + " to " + dir + " failed.", e);
        }

        return dir;
    }

    ////// RUNNING

    @SuppressWarnings({"unchecked"})
    public void start() {
        if (running) return;

        try {
            MutableServerStartupConfiguration cfg = new MutableServerStartupConfiguration();
            cfg.setWorkingDirectory(tempDir);
            cfg.setLdifDirectory(ldifDir);
            cfg.setEnableNetworking(true);
            cfg.setLdapPort(port);
            cfg.setAllowAnonymousAccess(allowAnonymous);
            cfg.setAccessControlEnabled(false);
            cfg.setShutdownHookEnabled(false);
            cfg.setContextPartitionConfigurations(
                Collections.singleton(createPartitionConfiguration()));
            if (!customSchemas.isEmpty()) {
                Set<BootstrapSchema> schemas = cfg.getBootstrapSchemas();
                for (Class<?> customSchemaClass : customSchemas) {
                    schemas.add((BootstrapSchema) customSchemaClass.newInstance());
                }
                cfg.setBootstrapSchemas(schemas);
            }

            new InitialDirContext(createJndiEnvironment(cfg));
        } catch (NamingException e) {
            throw new LadleFatalException("Startup failed", e);
        } catch (InstantiationException e) {
            throw new LadleFatalException("Custom schema not initializable", e);
        } catch (IllegalAccessException e) {
            throw new LadleFatalException("Custom schema not initializable", e);
        }

        running = true;
    }

    // Derived from http://directory.apache.org/apacheds/1.0/using-apacheds-for-unit-tests.html
    private MutablePartitionConfiguration createPartitionConfiguration() throws NamingException {
        MutablePartitionConfiguration pCfg = new MutablePartitionConfiguration();
        pCfg.setName("ladle");
        pCfg.setSuffix(domainComponent);

        Set<String> indexedAttrs = new HashSet<String>();
        indexedAttrs.add("objectClass");
        indexedAttrs.add("dc");
        indexedAttrs.add("uid");
        pCfg.setIndexedAttributes( indexedAttrs );

        // Create the root entry
        {
            Attributes attrs = new BasicAttributes(true);

            Attribute attr = new BasicAttribute("objectClass");
            attr.add("top");
            attr.add("domain");
            attrs.put(attr);

            attr = new BasicAttribute("dc");
            attr.add(domainComponent.split(",")[0].substring(3));
            attrs.put(attr);

            pCfg.setContextEntry(attrs);
        }

        return pCfg;
    }

    @SuppressWarnings({ "unchecked" })
    private Hashtable<String, String> createJndiEnvironment(Configuration cfg) {
        Hashtable<String, String> env = baseEnvironment();
        env.putAll(cfg.toJndiEnvironment());
        return env;
    }

    public void stop() {
        if (!running) return;
        try {
            new InitialDirContext(createJndiEnvironment(new ShutdownConfiguration()));
        } catch (NamingException e) {
            throw new LadleFatalException("Shutdown failed", e);
        }
        running = false;

        if (tempDir.exists()) {
            try {
                FileUtils.deleteDirectory(tempDir);
            } catch (IOException e) {
                log.error("Deleting the temporary directory " + tempDir + " failed", e);
            }
        }
    }

    public void setCustomSchemas(Collection<Class<?>> customSchemas) {
        this.customSchemas = customSchemas;
    }
}
