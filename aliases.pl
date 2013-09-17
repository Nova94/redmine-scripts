#!/usr/bin/env perl

use cat::db;

use strict;
use warnings;
use YAML qw(LoadFile);

my $config = LoadFile('config.yaml');
my $default_key = $config->{'default_key'};

my $dbh = cat::db::connectToDb('gitolite');


my $sql_count = "select count(*) from keys where state=?;";
my $sth_count = $dbh->prepare($sql_count);
$sth_count->execute('pending') or die "SQL Error: $DBI::errstr\n";
my $count_hash = $sth_count->fetchrow_hashref;
print $count_hash->{'count'};
print "\n";

if ( $count_hash->{'count'} > 0 )
    {
    my $sql = 'select * from keys';
    my $sth = $dbh->prepare($sql);

    $sth->execute or die "SQL Error: $DBI::errstr\n";

    while ( my $row = $sth->fetchrow_hashref )
        {
        my $uid  = $row->{'uid'};
        my $name = $row->{'name'};
        my $keydata = $row->{'keydata'};

        if ($keydata !~ /ssh-rsa/ && $keydata !~ /ssh-dsa/)
            {
            my $sql_update = "update keys set keydata = '" . $default_key . "' where uid = '" . $uid . "'";
            my $sth_update = $dbh->prepare($sql_update);
            $sth_update->execute or die "SQL Error: $DBI::errstr\n";
            }

        print "\@$uid = $name\n";

        }
    }

$sth_count->fetchrow_hashref;
$dbh->disconnect
