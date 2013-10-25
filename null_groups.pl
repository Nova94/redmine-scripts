#!/usr/bin/env perl

#This script finds users in the redmine database and gives them a default
#key in the gitolite database if they do not have one

use cat::db;

use strict;
use warnings;
use Path::Class;
use YAML qw(LoadFile);

my $config = LoadFile('config.yaml');
my $default_key_file_path = $config->{'default_key'};
my $default_key_file = file($default_key_file_path);
my $default_key = $default_key_file->slurp(chomp => 1);

my $dbh_gitolite = connectToDb('gitolite');
my $dbh_redmine = connectToDb('redmine');

my $users_sql = "select login from users where login != ''";
my $users_sth = $dbh_redmine->prepare($users_sql);

$users_sth->execute or die "SQL error: $DBI::errstr\n";

my $keys_sql = "select uid from keys";
my $keys_sth = $dbh_gitolite->prepare($keys_sql);
$keys_sth->execute or die "SQL error: $DBI::errstr\n";
my $keys = $keys_sth->fetchall_hashref('uid');

while ( my $user = $users_sth->fetchrow_hashref )
  {
    if ( !(exists(${$keys}{$user->{'login'}})) )
      {
        print "\@$user->{'login'} = NULL\n";
      }
  }

$dbh_gitolite->disconnect;
$dbh_redmine->disconnect;
