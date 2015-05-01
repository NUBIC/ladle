1.0.1
=====

- Use the more thorough tmpdir detection provided by `Dir.tmpdir`. (#21, @pirj)
- Treat unrecognized attributeType as bogus warning. (#25, @mtodd)


1.0.0
=====

- Updated to apacheDS 2.0.0-M16 from 1.0.2. (#14, #17, #18; @silarsis, @calavera, @http-418)
- BACKWARDS_INCOMPATIBLE CHANGE: Custom schemas are now defined in LDIF files,
  not via the former baroque java system. See CUSTOM-SCHEMA.md for details. (#14, @silarsis)
- Upgraded dependency to net-ldap-0.3.1 (#14, @silarsis)
- Added pom.xml to simplify downloading future apacheDS updates (#18, @http-418)
- Avoid EOF error on `Server#stop`. (#12; @iRyusa)
- Drop support for Ruby 1.8.7.

0.2.1
=====

- Improve error handling on newer versions of JRuby.
- Loosen open4 dependency for wider compatibility with other gems.
- Correct Cucumber snippets in readme. (#8)

0.2.0
=====

- Support custom schemas.

0.1.1
=====

- Allowed disabling anonymous access to the server.  See the
  `:allow_anonymous` option on {Ladle::Server#initialize}.
- Added passwords to default people.
- Internal: ensured that specs properly close sockets so that the
  suite will pass on Linux.

0.1.0
=====

- Initial release
