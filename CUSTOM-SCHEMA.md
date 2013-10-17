Custom Schemas in Ladle
=======================

If you need to use LDAP classes other the standard ones, you'll need
to define and include a custom schema.  There are three steps in this
process:

Create or obtain the schema in openldap format
----------------------------------------------

All the details are there in the step name.

Generate the java representation of the schema
----------------------------------------------

The embedded LDAP server in ladle is ApacheDS 1.0.2.  That project
provides [documentation][ds-custom] of how to build custom schemas;
look at the section titled "Creating a Maven module for your custom
schema."  As you might guess from the title, you'll need [maven
2][mvn] to do this.

The process has one snag -- after you generate the schema using
`apacheds-schema-archetype.sh`, you'll need to modify the generated
`pom.xml`.  Under the this code:

    <plugins>
      <plugin>
        <groupId>org.apache.directory.server</groupId>
        <artifactId>apacheds-core-plugin</artifactId>

Add the line:

        <version>1.0.2</version>

Then continue with the directions.

[ds-custom]: https://cwiki.apache.org/confluence/display/DIRxSRVx10/Custom+Schema
[mvn]: http://maven.apache.org/

Configure ladle to use the custom schema
----------------------------------------

At the end of the java schema generation step, you'll have a jar file
under `target` containing several classes representing the the schema.
Put that jar somewhere in your project, then configure the
{Ladle::Server} instance to point to it:

    Ladle::Server.new(
      :additional_classpath => %w(path/to/sample-schema-1.0-SNAPSHOT.jar),
      :custom_schemas => %w(com.example.schema.TestSchema),
      :ldif => "path/to/schema-using.ldif",
      :domain => "dc=example,dc=com"
    )

The custom schema classname is derived from the first argument you
passed to `apacheds-schema-archtype.sh` and the name of your schema
file.  In the example above, it's as if you ran

    apacheds-schema-archetype.sh com.example.schema sample-schema

And then named the schema file `test.schema`.
