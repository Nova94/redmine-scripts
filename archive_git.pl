#!/usr/bin/env perl

#
# Archive git repos that need to be deleted
#

use strict;
use warnings;

use cat::db;

use Path::Class;
use Data::Dumper;

use YAML qw(LoadFile);

my $config = LoadFile('config.yaml');
my $gitroot = $config->{'git_root'};

my $dbh = cat::db::connectToDb('gitolite');

my $sql = "select * from projects where status = 'deleting' AND type = 'Git'";
my $sth = $dbh->prepare($sql);

$sth->execute or die "SQL Error: $DBI::errstr\n";

if ( ! -d ($gitroot . '/archive') )
    {
    if ( ! mkdir($gitroot . '/archive') )
	{
	print "something went boom\n";
	}

    }

while ( my $row = $sth->fetchrow_hashref )
    {
    my $requestor = $row->{'requestor'};
    my $name = $row->{'name'};

    if ( rename("${gitroot}${requestor}-${name}.git",
	"${gitroot}archive/${requestor}-${name}.git" ) )
	{
        print "Archived respository $requestor-$name\n";

    my $identifier = $row->{'identifier'};
	my $sth2 = $dbh->prepare("UPDATE projects set status = 'deleted' WHERE identifier = ?");

	$sth2->execute($identifier)  or die "SQL Error: $DBI::errstr\n";
	}
    else
	{
	print "something went wrong with archiving $name\n";
	}
    }



$dbh->disconnect

