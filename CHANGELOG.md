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
