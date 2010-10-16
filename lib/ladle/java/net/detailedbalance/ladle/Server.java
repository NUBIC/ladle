package net.detailedbalance.ladle;

import org.apache.commons.io.FileUtils;
import org.apache.directory.server.core.DefaultDirectoryService;
import org.apache.directory.server.core.DirectoryService;
import org.apache.directory.server.core.authn.AuthenticationInterceptor;
import org.apache.directory.server.core.entry.ServerEntry;
import org.apache.directory.server.core.exception.ExceptionInterceptor;
import org.apache.directory.server.core.interceptor.Interceptor;
import org.apache.directory.server.core.normalization.NormalizationInterceptor;
import org.apache.directory.server.core.operational.OperationalAttributeInterceptor;
import org.apache.directory.server.core.partition.impl.btree.jdbm.JdbmPartition;
import org.apache.directory.server.core.referral.ReferralInterceptor;
import org.apache.directory.server.core.subtree.SubentryInterceptor;
import org.apache.directory.server.ldap.LdapServer;
import org.apache.directory.server.protocol.shared.store.LdifFileLoader;
import org.apache.directory.server.protocol.shared.transport.TcpTransport;
import org.apache.directory.shared.ldap.exception.LdapNameNotFoundException;
import org.apache.directory.shared.ldap.name.LdapDN;
import org.apache.log4j.Logger;

import java.io.File;
import java.io.IOException;
import java.util.Arrays;
import java.util.UUID;

/**
 * The class that creates and controls an embedded ApacheDS instance.  This runner is not designed
 * for thread-safety or even to be used in the same JVM as anything else -- it's intended to be run
 * in its own process to provide LDAP access over TCP.
 * <p>
 * The idea of using ApacheDS for this, as well as some of the details, are from Spring Security's
 * LDAP test support.
 */
public class Server {
    private final Logger log = Logger.getLogger(getClass());

    private final int port;
    private final String domainComponent;
    private final File tempDir;
    private final DefaultDirectoryService service;
    private final LdapServer server;
    private boolean running = false;

    public Server(int port, String domainComponent, File ldifFile, File tempDirBase) {
        this.port = port;
        this.domainComponent = domainComponent;
        this.tempDir = createTempDir(tempDirBase);

        this.service = createAndStartDirectoryService();
        this.server = createServer();
        importLdif(ldifFile);
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

    private DefaultDirectoryService createAndStartDirectoryService() {
        log.info("Creating ApacheDS directory service");
        DefaultDirectoryService svc = new DefaultDirectoryService();

        // There is no high-level documentation of what interceptors are needed for what server
        // types (etc), so this list is cargo-culted from Spring Security's ApacheDSContainer.
        // Seems to work.
        svc.setInterceptors(Arrays.<Interceptor>asList(
            new NormalizationInterceptor(),
            new AuthenticationInterceptor(),
            new ReferralInterceptor(),
            new ExceptionInterceptor(),
            new OperationalAttributeInterceptor(),
            new SubentryInterceptor()
        ));

        JdbmPartition root;
        try {
            root = new JdbmPartition();
            root.setId("rootPartition");
            root.setSuffix(domainComponent);
            svc.addPartition(root);
        } catch (Exception e) {
            throw new LadleFatalException("Failed to create partition", e);
        }

        svc.setShutdownHookEnabled(false);
        svc.setExitVmOnShutdown(false);
        svc.getChangeLog().setEnabled(false);
        svc.setWorkingDirectory(tempDir);

        try {
            log.info("Starting ApacheDS directory service");
            svc.startup();
        } catch (Exception e) {
            throw new LadleFatalException("Failed to start directory service", e);
        }

        try {
            svc.getAdminSession().lookup(root.getSuffixDn());
        } catch (LdapNameNotFoundException e) {
            createAndAddDomainComponentEntry(svc);
        } catch (Exception e) {
            throw new LadleFatalException("Failed to look up existing root DN", e);
        }

        return svc;
    }

    private void createAndAddDomainComponentEntry(DirectoryService svc) {
        String dc = domainComponent.split(",")[0].substring(3);
        try {
            LdapDN dn = new LdapDN(domainComponent);
            ServerEntry entry = svc.newEntry(dn);
            entry.add("objectClass", "top", "domain");
            entry.add("dc", dc);
            svc.getAdminSession().add(entry);
        } catch (Exception e) {
            throw new LadleFatalException("Failed to create DC entry for " + domainComponent, e);
        }
    }

    private LdapServer createServer() {
        LdapServer svr = new LdapServer();
        svr.setDirectoryService(service);
        svr.setTransports(new TcpTransport(port));
        return svr;
    }

    private void importLdif(File ldifFile) {
        log.info("Importing from LDIF " + ldifFile);
        LdifFileLoader loader = new LdifFileLoader(
            service.getAdminSession(), ldifFile.getAbsolutePath());
        loader.execute();
    }

    ////// RUNNING

    public void start() {
        if (running) return;

        try {
            server.start();
        } catch (Exception e) {
            throw new LadleFatalException("LDAP server start failed", e);
        }

        running = true;
    }

    public void stop() {
        if (!running) return;
        server.stop();
        try {
            service.shutdown();
        } catch (Exception e) {
            log.error("Shutting down the directory service failed", e);
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
}
