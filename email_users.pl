#!/usr/bin/env perl

use strict;
use warnings;
use cat::db;

#Load the database and yaml file
my $dbh = cat::db::connectToDb('gitolite');
use YAML qw(LoadFile);
my $config = LoadFile('config.yaml');

my $sql_query = "select * from projects where status = 'pending';";
my $sth_query = $dbh->prepare($sql_query);
$sth_query->execute or die "SQL Error: $DBI::errstr\n";

while ( my $row = $sth_query->fetchrow_hashref )
    {
    my $type = $row->{'type'};
    my $requestor = $row->{'requestor'};
    my $name = $row->{'name'};
    my $message;
    my $emaildir = $config->{'emaildir'};
    my $redmine_url = $config->{'redmine_url'};
    my $git_url = $config->{'git_url'};

    if ($type eq "Git")
        {
        open(FILE, "$emaildir/git_repo_creation_email") or die "Can't read email file\n";
        local $/;
        $message = <FILE>;
        }
    elsif ($type eq "Svn")
        {
        open(FILE, "$emaildir/svn_repo_creation_email") or die "Can't read email file\n";
        local $/;
        $message = <FILE>;
        }
    else 
        { 
        next; 
        }

    # This performs $var variable expansion
    $message =~ s/(\$\w+)/$1/eeg;

    my $sendmail = '/usr/sbin/sendmail -t';
    my $from = "From: redmine\@cecs.pdx.edu\n";
    my $subject = "Subject: $name\'s $type repo has been created\n";
    my $send_to = "To: $requestor\@cecs.pdx.edu\n";

    open(SENDMAIL, "|$sendmail") or die "Cannot open $sendmail";
    print SENDMAIL $from;
    print SENDMAIL $subject;
    print SENDMAIL $send_to;
    print SENDMAIL "Content-type: text/plain\n\n";
    print SENDMAIL $message;
    close(SENDMAIL);
    }

$dbh->disconnect;
