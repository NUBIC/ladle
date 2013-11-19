Ladle
=====

Ladle dishes out steaming helpings of lightweight directory access
(LDAP) for use in testing with rspec, cucumber, or any other ruby test
framework.

It spins up an actual LDAP server instance, so you can use it to test
any sort of client application &mdash; anything that communicates over
the standard LDAP protocol.

Ladle itself is tested on both JRuby 1.7.4 and Ruby 1.8.7, 1.9.3, and 2.0.0.
It is a wrapper around [ApacheDS][] (a pure-java embeddable LDAP
server), so it needs Java 1.5 or later available whether you are using
JRuby or not.

Ladle will not work with MRI on Windows. (A pull request adding this support
would be eagerly reviewed.) It should work with JRuby on Windows, though this
hasn't been tested.

[ApacheDS]: http://directory.apache.org/apacheds/1.0/index.html

Ladle in 30 seconds
-------------------

To use Ladle, first create a server with some data:

    server = Ladle::Server.new(
      :port   => 3897,
      :ldif   => "test_users.ldif",
      :domain => "dc=test"
    )

Then start the server:

    server.start

At this point, you have an LDAP server running on port 3897 with your
specified groups and people in it.  When you're done with it, just
tell it to stop:

    server.stop

Ladle with a test framework
---------------------------

Depending on what you're doing, you might want to run one
{Ladle::Server} for all your tests, or have a clean one for each test.
Since it takes a few seconds to spin up the server, if you are only
reading from the server, it makes sense to use one for all your tests.
If you are doing writes, a separate server for each test is safer.

All decent test frameworks can support either mode.  Some examples:

### RSpec

To use a server per test, configure and start it in a normal `before`
block, then stop it in an `after` block:

    describe "directory access" do
      before do
        @ldap_server = Ladle::Server.new(:quiet => true).start
      end

      after do
        @ldap_server.stop if @ldap_server
      end

      it "is possible" do
        # ...
      end
    end

For a shared server, use `before(:all)` and `after(:all)` instead.
See [rspec's docs][rspec-before] for more info.

[rspec-before]: http://rspec.info/documentation/before_and_after.html

### Cucumber

To use a server per test, use Cucumber's `Around` [hook][cucumber-hooks]:

    Around('@ldap') do |scenario, block|
      ladle = Ladle::Server.new(:quiet => true).start
      block.call
      ladle.stop
    end

If you want just one server, consider something like this:

    Before('@ldap') do
      $ladle ||= Ladle::Server.new(:quiet => true).start
    end

This will start up a server for the first feature which needs it (and
has indicated that with the `@ldap` tag).  The server will remain
running for all subsequent features and automatically shut down at the
end of the run.  (Cucumber's hooks documentation notes that you would,
in general, need to register an `at_exit` block for the process to be
torn down at the end.  {Ladle::Server#start} does this automatically.)

[cucumber-hooks]: http://github.com/cucumber/cucumber/wiki/hooks

Test data
---------

Ladle accepts data in the [standard][rfc2849] LDIF format.  If you do
not specify an LDIF file when creating the server, ladle will use its
default data.  You can peruse it in `lib/ladle/default.ldif`.

Note also that you will usually need to provide both the `:ldif` and
`:domain` configuration parameters.  The latter must be the domain
component (dc) matching the data in the former.  (N.b. the implicit
restriction of the data to a single domain.)

[rfc2849]: http://tools.ietf.org/rfc/rfc2849.txt

Additional classes
------------------

If you need to use LDAP classes that are not among the standard set
provided by ApacheDS, you'll need to specify a custom schema.  See
{file:CUSTOM-SCHEMA.md} for details.

Project links
-------------

* [API documentation](http://rubydoc.info/github/NUBIC/ladle/master/frames)
* [Continuous integration](https://travis-ci.org/NUBIC/ladle)
* [Issue tracking](http://github.com/NUBIC/ladle/issues)

Non-issue questions can be sent to rhett@detailedbalance.net.

About
-----

Ladle is copyright 2010 Rhett Sutphin.  It was built at [NUBIC][].
See the `NOTICE` file alongside this one for copyright information
about software ladle depends on and redistributes.

[NUBIC]: http://www.nucats.northwestern.edu/centers/nubic
