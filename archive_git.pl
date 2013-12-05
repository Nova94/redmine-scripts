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

    open(FILE, 'email_forms/git_repo_deletion_email') or die "Cannot read repo deletion email file\n";
    local $/;
    my $message = <FILE>;
    $message =~ s/(\$\w+)/$1/eeg;

    my $sendmail = '/usr/sbin/sendmail -t';
    my $from = "From: redmine\@cecs.pdx.edu\n";
    my $subject = "Subject: The git repo for your redmine project $name has been deleted\n";
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

