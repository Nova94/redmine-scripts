#!/usr/bin/env perl

#
# Make any pending svn repositories, or delete any that need deleting
#

use strict;
use warnings;

use cat::db;

use Path::Class;
use Data::Dumper;

use YAML qw(LoadFile);

my $config = LoadFile('config.yaml');
my $svnroot = $config->{'svn_root'};

my $dbh = cat::db::connectToDb('gitolite');
my $sql = "select * from projects where status = 'pending' AND type = 'Svn'";
my $sth = $dbh->prepare($sql);

$sth->execute or die "SQL Error: $DBI::errstr\n";

while ( my $row = $sth->fetchrow_hashref )
    {
    my $identifier = $row->{'identifier'};

    if ( system("svnadmin create --fs-type fsfs ${svnroot}/${identifier}" ) )
	{
	print $?, "\n";
	print "something went boom\n";
	}
    else
	{
	printf("Repository created: %s/%s\n", $svnroot, $identifier);

	my $sth2 = $dbh->prepare("UPDATE projects set status = 'present' WHERE identifier = ?");

	$sth2->execute($identifier)  or die "SQL Error: $DBI::errstr\n";
	}

    }

$sql = "select * from projects where status = 'deleting' AND type = 'Svn'";
$sth = $dbh->prepare($sql);

$sth->execute or die "SQL Error: $DBI::errstr\n";

if ( ! -d $svnroot )
    {
    if ( ! mkdir($svnroot . '/archive') )
	{
	print "something went boom\n";
	}

    }

while ( my $row = $sth->fetchrow_hashref )
    {
    my $identifier = $row->{'identifier'};


    if ( rename("${svnroot}/${identifier}",
	"${svnroot}/archive/${identifier}" ) )
	{
        print "Archived respository $identifier\n";

	my $sth2 = $dbh->prepare("UPDATE projects set status = 'deleted' WHERE identifier = ?");

	$sth2->execute($identifier)  or die "SQL Error: $DBI::errstr\n";
	}
    else
	{
	print "something went wrong with archiving $identifier\n";
	}
    }



$dbh->disconnect

