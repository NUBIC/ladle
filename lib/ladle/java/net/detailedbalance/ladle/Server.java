package net.detailedbalance.ladle;

import org.apache.commons.io.FileUtils;
import org.apache.directory.api.ldap.model.entry.Entry;
import org.apache.directory.api.ldap.model.entry.DefaultEntry;
import org.apache.directory.api.ldap.model.exception.LdapException;
import org.apache.directory.api.ldap.model.name.Dn;
import org.apache.directory.api.ldap.model.schema.SchemaManager;
import org.apache.directory.api.ldap.model.schema.registries.SchemaLoader;
import org.apache.directory.api.ldap.model.ldif.LdifReader;
import org.apache.directory.api.ldap.model.ldif.LdifEntry;
import org.apache.directory.api.ldap.schemaextractor.SchemaLdifExtractor;
import org.apache.directory.api.ldap.schemaextractor.impl.DefaultSchemaLdifExtractor;
import org.apache.directory.api.ldap.schemaloader.LdifSchemaLoader;
import org.apache.directory.api.ldap.schemamanager.impl.DefaultSchemaManager;
import org.apache.directory.api.util.exception.Exceptions;
import org.apache.directory.server.constants.ServerDNConstants;
import org.apache.directory.server.core.DefaultDirectoryService;
import org.apache.directory.server.core.api.CacheService;
import org.apache.directory.server.core.api.DirectoryService;
import org.apache.directory.server.core.api.InstanceLayout;
import org.apache.directory.server.core.api.partition.Partition;
import org.apache.directory.server.core.api.schema.SchemaPartition;
import org.apache.directory.server.core.partition.impl.btree.jdbm.JdbmIndex;
import org.apache.directory.server.core.partition.impl.btree.jdbm.JdbmPartition;
import org.apache.directory.server.core.partition.ldif.LdifPartition;
import org.apache.directory.server.i18n.I18n;
import org.apache.directory.server.ldap.LdapServer;
import org.apache.directory.server.protocol.shared.transport.TcpTransport;
import org.apache.directory.server.protocol.shared.store.LdifFileLoader;
import org.apache.directory.server.core.api.CoreSession;
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
import java.io.InputStream;
import java.io.FileInputStream;
import java.util.Collection;
import java.util.Collections;
import java.util.HashSet;
import java.util.Hashtable;
import java.util.Set;
import java.util.List;
import java.util.UUID;

/**
 * The class that creates and controls an embedded ApacheDS instance.  This runner is not designed
 * for thread-safety or even to be used in the same JVM as anything else -- it's intended to be run
 * in its own process to provide LDAP access over TCP.
 * <p>
 * The idea of using ApacheDS for this was from Spring Security's LDAP test support.  The details
 * are from the ApacheDS embedding and unit testing documentation.
 * <p>
 * This file has been greatly modified to support apacheDS 2.0, based predominantly on
 * http://svn.apache.org/repos/asf/directory/sandbox/kayyagari/embedded-sample-trunk/src/main/java/org/apache/directory/seserver/EmbeddedADSVerTrunk.java
 */
public class Server {
    private final Logger log = Logger.getLogger(getClass());

    private final int port;
    private final String domainComponent;
    private final boolean allowAnonymous;
    private final File tempDir;
    private final String ldifFile;
    private final File ldifDir;
    private boolean running = false;
    private Collection<Class<?>> customSchemas = Collections.emptyList();

    private DirectoryService service;
    private LdapServer ldapServer;

    public Server(
        int port, String domainComponent, File ldifFile, File tempDirBase, boolean allowAnonymous
    ) {
        this.port = port;
        this.domainComponent = domainComponent;
        this.allowAnonymous = allowAnonymous;
        this.tempDir = createTempDir(tempDirBase);
        this.ldifFile = ldifFile.getPath();
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

    @SuppressWarnings(value={"unchecked"})
    public void start() throws Exception {
        if (running) return;

        try {
            // Initialize the LDAP service
            service = new DefaultDirectoryService();
            service.setInstanceLayout( new InstanceLayout( tempDir ) );
            
            CacheService cacheService = new CacheService();
            cacheService.initialize( service.getInstanceLayout() );

            service.setCacheService( cacheService );
            
            // first load the schema
            initSchemaPartition();
            
            // then the system partition
            // this is a MANDATORY partition
            // DO NOT add this via addPartition() method, trunk code complains about duplicate partition
            // while initializing 
            JdbmPartition systemPartition = new JdbmPartition(service.getSchemaManager());
            systemPartition.setId( "system" );
            systemPartition.setPartitionPath( new File( service.getInstanceLayout().getPartitionsDirectory(), systemPartition.getId() ).toURI() );
            systemPartition.setSuffixDn( new Dn( ServerDNConstants.SYSTEM_DN ) );
            systemPartition.setSchemaManager( service.getSchemaManager() );

            // mandatory to call this method to set the system partition
            // Note: this system partition might be removed from trunk
            service.setSystemPartition( systemPartition );
            
            // Disable the ChangeLog system
            service.getChangeLog().setEnabled( false );
            service.setDenormalizeOpAttrsEnabled( true );

            // Now we can create as many partitions as we need
            Partition ladlePartition = addPartition( "ladle", domainComponent );
            addIndex( ladlePartition, "objectClass", "ou", "dc", "uid" );
            service.setAllowAnonymousAccess( allowAnonymous );
            service.startup();

             // Inject the context entry for the partition if it does not already exist
            try
            {
                service.getAdminSession().lookup( ladlePartition.getSuffixDn() );
            }
            catch ( LdapException lnnfe )
            {
                Dn userDN = new Dn( domainComponent );
                Entry userEntry = service.newEntry( userDN );
                userEntry.add( "objectClass", "top", "domain", "extensibleObject" );
                userEntry.add( "dc", domainComponent.split(",")[0].substring(3) );
                service.getAdminSession().add( userEntry );
            }

            // Load up any extra data
            loadLDIF(ldifFile);

            // Now create the LDAP server and transport for the Directory Service.
            ldapServer = new LdapServer();
            ldapServer.setDirectoryService( service );
            TcpTransport ldapTransport = new TcpTransport( port );
            ldapServer.setTransports( ldapTransport );
            ldapServer.start();
        } catch (NamingException e) {
            throw new LadleFatalException("Startup failed", e);
        } catch (InstantiationException e) {
            throw new LadleFatalException("Custom schema not initializable", e);
        } catch (IllegalAccessException e) {
            throw new LadleFatalException("Custom schema not initializable", e);
        }

        running = true;
    }

    public void loadLDIF(String filepath) throws Exception {  
          
        log.info("Loading : " + filepath);

        if (!service.isStarted()) {
            throw new Exception("Directory service not started");
        } else {
            InputStream is = null;
            SchemaManager schemaManager = service.getSchemaManager();
            try {
                is = new FileInputStream(filepath);
                if (is != null) {
                    LdifReader entries = new LdifReader(is);
                    for (LdifEntry ldifEntry : entries) {
                        DefaultEntry newEntry = new DefaultEntry(schemaManager, ldifEntry.getEntry());
                        service.getAdminSession().add( newEntry );
                    }
                }
            } finally {
                if (is != null) is.close();
            }
        }
    }

    /**
     * Add a new partition to the server
     *
     * @param partitionId The partition Id
     * @param partitionDn The partition DN
     * @return The newly added partition
     * @throws Exception If the partition can't be added
     */
    private Partition addPartition( String partitionId, String partitionDn ) throws Exception
    {
        // Create a new partition with the given partition id 
        JdbmPartition partition = new JdbmPartition(service.getSchemaManager());
        partition.setId( partitionId );
        partition.setPartitionPath( new File( service.getInstanceLayout().getPartitionsDirectory(), partitionId ).toURI() );
        partition.setSuffixDn( new Dn( partitionDn ) );
        service.addPartition( partition );
        
        return partition;
    }

    /**
     * initialize the schema manager and add the schema partition to diectory service
     *
     * @throws Exception if the schema LDIF files are not found on the classpath
     */
    private void initSchemaPartition() throws Exception
    {
        InstanceLayout instanceLayout = service.getInstanceLayout();
        
        File schemaPartitionDirectory = new File( instanceLayout.getPartitionsDirectory(), "schema" );

        // Extract the schema on disk (a brand new one) and load the registries
        if ( schemaPartitionDirectory.exists() )
        {
            log.warn( "schema partition already exists, skipping schema extraction" );
        }
        else
        {
            SchemaLdifExtractor extractor = new DefaultSchemaLdifExtractor( instanceLayout.getPartitionsDirectory() );
            extractor.extractOrCopy();
        }

        SchemaLoader loader = new LdifSchemaLoader( schemaPartitionDirectory );
        SchemaManager schemaManager = new DefaultSchemaManager( loader );

        // We have to load the schema now, otherwise we won't be able
        // to initialize the Partitions, as we won't be able to parse
        // and normalize their suffix Dn
        schemaManager.loadAllEnabled();

        List<Throwable> errors = schemaManager.getErrors();

        if ( errors.size() != 0 )
        {
            throw new Exception( I18n.err( I18n.ERR_317, Exceptions.printErrors( errors ) ) );
        }

        service.setSchemaManager( schemaManager );
        
        // Init the LdifPartition with schema
        LdifPartition schemaLdifPartition = new LdifPartition( schemaManager );
        schemaLdifPartition.setPartitionPath( schemaPartitionDirectory.toURI() );

        // The schema partition
        SchemaPartition schemaPartition = new SchemaPartition( schemaManager );
        schemaPartition.setWrappedPartition( schemaLdifPartition );
        service.setSchemaPartition( schemaPartition );
    }

    /**
     * Add a new set of index on the given attributes
     *
     * @param partition The partition on which we want to add index
     * @param attrs The list of attributes to index
     */
    private void addIndex( Partition partition, String... attrs )
    {
        // Index some attributes on the apache partition
        Set indexedAttributes = new HashSet();

        for ( String attribute : attrs )
        {
            indexedAttributes.add( new JdbmIndex<String, Entry>( attribute, false ) );
        }

        ( ( JdbmPartition ) partition ).setIndexedAttributes( indexedAttributes );
    }

    public void stop() throws LadleFatalException {
        if (!running) return;
        try {
            service.shutdown();
        } catch (Exception e) {
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
