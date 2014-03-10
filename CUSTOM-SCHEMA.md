Custom Schemas in Ladle
=======================

If you need to use LDAP classes other the standard ones, you'll need
to define and include a custom schema.  As of version 2.0 of apacheDS,
this is done via ldif files. Put simply, you can create the appropriate
schema elements in a stand-alone ldif file and specify that be loaded
prior to any data files.

For an example of how this should look, please reference
spec/ladle/animals-custom-schema.ldif

CN=other,OU=schema is a good place to put your own custom attributes
and object types. There is a "test branch" starting with 2.25 which can
be used for self-generated oids, if you're making things up yourself
- check http://stackoverflow.com/questions/725837/experimental-private-branch-for-oid-numbers-in-ldap-schemas
for more info.

Configure ladle to use the custom schema
----------------------------------------

Put the ldif somewhere in your project, then configure the
{Ladle::Server} instance to point to it:

    Ladle::Server.new(
      :additional_classpath => %w(path/to/sample-schema-1.0-SNAPSHOT.jar),
      :custom_schemas => "path/to/schema.ldif",
      :ldif => "path/to/schema-using.ldif",
      :domain => "dc=example,dc=com"
    )

Note, you can also build the schema into the schema-using ldif, at a pinch.