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
    my $requestor = $row->{'requestor'};
    my $name = $row->{'name'};

    if ( system("svnadmin create --fs-type fsfs ${svnroot}${requestor}-${name}" ) )
	{
	print $?, "\n";
	print "something went boom\n";
	}
    else
	{
	printf("Repository created: %s%s-%s\n", $svnroot, $requestor, $name);

    #setting the status is now handled later in update-gitolite.pl
    #my $sth2 = $dbh->prepare("UPDATE projects set status = 'present' WHERE identifier = ?");

    #$sth2->execute($identifier)  or die "SQL Error: $DBI::errstr\n";
	}

    }

$sql = "select * from projects where status = 'deleting' AND type = 'Svn'";
$sth = $dbh->prepare($sql);

$sth->execute or die "SQL Error: $DBI::errstr\n";

if ( ! -d ($svnroot . '/archive') )
    {
    if ( ! mkdir($svnroot . '/archive') )
	{
	print "something went boom\n";
	}

    }

while ( my $row = $sth->fetchrow_hashref )
    {
    my $requestor = $row->{'requestor'};
    my $name = $row->{'name'};

    if ( rename("${svnroot}${requestor}-${name}",
	"${svnroot}archive/${requestor}-${name}" ) )
	{
        print "Archived respository $requestor-$name\n";

    email($row);

    my $identifier = $row->{'identifier'};
	my $sth2 = $dbh->prepare("UPDATE projects set status = 'deleted' WHERE identifier = ?");

	$sth2->execute($identifier)  or die "SQL Error: $DBI::errstr\n";
	}
    else
	{
	print "something went wrong with archiving $name\n";
	}
    }

sub email 
    {
    my ($row) = @_;

    my $requestor = $row->{'requestor'};
    my $name = $row->{'name'};

    open(FILE, 'email_forms/svn_repo_deletion_email') or die "Cannot read repo deletion email file\n";
    local $/;
    my $message = <FILE>;
    $message =~ s/(\$\w+)/$1/eeg;

    my $sendmail = '/usr/sbin/sendmail -t';
    my $from = "From: redmine\@cecs.pdx.edu\n";
    my $subject = "Subject: $name\'s svn repo has been deleted\n";
    my $send_to = "To: $requestor\@cecs.pdx.edu\n";

    open(SENDMAIL, "|$sendmail") or die "Cannot open $sendmail";
    print SENDMAIL $from;
    print SENDMAIL $subject;
    print SENDMAIL $send_to;
    print SENDMAIL "Content-type: text/plain\n\n";
    print SENDMAIL $message;
    close(SENDMAIL);
    }


$dbh->disconnect

