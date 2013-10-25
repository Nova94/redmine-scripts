#!/usr/bin/env perl

use cat::db;

use strict;
use warnings;
use Path::Class;
use YAML qw(LoadFile);

my $dbh = cat::db::connectToDb('gitolite');


my $sql_count = "select count(*) from keys where state=?;";
my $sth_count = $dbh->prepare($sql_count);
$sth_count->execute('pending') or die "SQL Error: $DBI::errstr\n";
my $count_hash = $sth_count->fetchrow_hashref;

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

        print "\@$uid = $name\n";

        }
    }

$sth_count->fetchrow_hashref;
$dbh->disconnect
