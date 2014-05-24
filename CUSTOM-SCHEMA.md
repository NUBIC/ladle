Custom Schemas in Ladle
=======================

If you need to use LDAP classes other the standard ones, you'll need to define
and include a custom schema.  As of version 2.0 of apacheDS, this is done via
ldif files. You can create the appropriate schema elements in a stand-alone ldif
file and specify that be loaded prior to any data files.

For an example of how this should look, please refer to
`spec/ladle/animals-custom-schema.ldif`.

`CN=other,OU=schema` is a good place to put your own custom attributes
and object types. There is a "test branch" starting with 2.25 which can
be used for self-generated oids, if you're making things up yourself
- check [this stackoverflow question][so] for more info.

[so]: http://stackoverflow.com/questions/725837/experimental-private-branch-for-oid-numbers-in-ldap-schemas

Configure ladle to use the custom schema
----------------------------------------

Put the ldif somewhere in your project, then configure the
{Ladle::Server} instance to point to it:

    Ladle::Server.new(
      :custom_schemas => "path/to/schema.ldif",
      :ldif => "path/to/data-that-uses-the-schema.ldif",
      :domain => "dc=example,dc=com"
    )

You may also combine the custom schema declarations in the data LDIF (the file
named by the `:ldif` option). If you do this, do can skip the `:custom_schemas`
option entirely. The separate `:custom_schemas` option is nice if you use the
same schema but different data in different tests, or if you use an externally-
provided schema. If your tests aren't that complicated, then combining them into
one file has no downsides.
