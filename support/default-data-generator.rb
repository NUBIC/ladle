#!/usr/bin/env ruby

# This is the script that's used to regenerate the default data for
# ladle.  When you run the script, the data goes to standard out;
# redirect it to a file to save it.

require 'erb'
require 'sha1'
require 'base64'

# Ensure that the "random" numbers in the usernames are stable.
srand(0)

NAMES = [
  %w(Alexandra Adams),
  %w(Belle Baldwin),
  %w(Claire Carpenter),
  %w(Dorothy Dawson),
  %w(Elizabeth Emerson),
  %w(Freya Fuller),
  %w(Grace Gonzales),
  %w(Hilda Hatfield),
  %w(Iona Ingram),
  %w(Josephine Jackson),
  %w(Kelly Kline),
  %w(Leah Lawrence),
  %w(Mona Maddox),
  %w(Noel Nash),
  %w(Ophelia Osborn),
  %w(Penelope Patel),
  %w(Quin Queen),
  %w(Ruth Rowland),
  %w(Serena Solomon),
  %w(Talia Torres),
  %w(Ursula Underwood),
  %w(Vera Vickers),
  %w(Wendy Wise),
  %w(Xara Xiong),
  %w(Yvette Yates),
  %w(Zana Zimmerman)
];

TEMPLATE = ERB.new(<<-ERB)
dn: uid=<%= p.uid %>,ou=people,dc=example,dc=org
objectClass: top
objectClass: person
objectClass: organizationalPerson
objectClass: inetOrgPerson
cn: <%= p.first %> <%= p.last %>
sn: <%= p.last %>
givenName: <%= p.first %>
mail: <%= p.mail %>
uid: <%= p.uid %>
# Password is "<%= p.password %>"
userpassword: {SHA}<%= p.password_hash %>
ERB

class Person
  attr_reader :first, :last, :uid

  def initialize(first, last)
    @first = first
    @last = last
    @uid = "#{first[0,1] * 2}#{rand_uid}".downcase
  end

  def mail
    "#{first.downcase}@example.org"
  end

  def password
    last.downcase.reverse
  end

  def password_hash
    Base64.encode64(SHA1.sha1(password).digest).strip
  end

  private

  def rand_uid
    v = 1
    until v % 9 == 0
      v = rand(900) + 100
    end
    v
  end
end

puts <<-HEADER
version: 1

dn: ou=people,dc=example,dc=org
objectClass: top
objectClass: organizationalUnit
ou: people

HEADER

NAMES.each { |f, l|
  p = Person.new(f, l)
  puts TEMPLATE.result(binding), ""
}
