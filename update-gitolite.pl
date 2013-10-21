#!/usr/bin/env perl

use strict;
use warnings;
use cat::db;

#Load the database and yaml file
my $dbh = cat::db::connectToDb('gitolite');
use YAML qw(LoadFile);
my $config = LoadFile('config.yaml');

#make sure we're in the correct directory
chdir $config->{'redmine_scripts_path'};


#Update the projects db if there are any pending projects
my $sql_count = "select count(*) from projects where status='pending' or status = 'deleting';";
my $sth_count = $dbh->prepare($sql_count);
$sth_count->execute or die "SQL Error: $DBI::errstr\n";
my $count_hash = $sth_count->fetchrow_hashref;

if ( $count_hash->{'count'} > 0 ) {
    system ("./gitolite-redmine.pl > " . $config->{'gitolite_admin_path'} . "conf/projects.conf");
}

$sth_count->fetchrow_hashref;


#delete old keys from the gitolite keydir
system("./delete_keys.pl " . $config->{'gitolite_admin_path'} . "keydir");

#Update the keys database if there are pending keys
$sql_count = "select count(*) from keys where state='pending';";
$sth_count = $dbh->prepare($sql_count);
$sth_count->execute or die "SQL Error: $DBI::errstr\n";
$count_hash = $sth_count->fetchrow_hashref;

if ( $count_hash->{'count'} > 0 ) {
    system("./aliases.pl > " . $config->{'gitolite_admin_path'} . "conf/aliases.conf");
}

$sth_count->fetchrow_hashref;

#Create user groups for users with no keys
system ("./null_groups.pl > " . $config->{'gitolite_admin_path'} . "conf/nokeys.conf");

#add new keys to the gitolite keydir
system("./add_keys.pl " . $config->{'gitolite_admin_path'} . "keydir");


#Create git repos
chdir $config->{'gitolite_admin_path'};
if ( `git status` !~ /nothing to commit/ ) {
    system("git add -A");
    system("git commit -m \"Commit through update-gitolite.pl\"");
    system("git push");
}
chdir $config->{'redmine_scripts_path'};

#Create svn repos
system("./makesvn.pl");

#update redmine
system("./sync_redmine.pl");


#Set any pending projects to present
my $sql_update = "update projects set status = 'present' where status = 'pending';";
my $sth_update = $dbh->prepare($sql_update);
$sth_update->execute or die "SQL Error: $DBI::errstr\n";

#Set git projects to be "deleted"
#Svn projects are deleted in makesvn.pl
my $sql_delete = "update projects set status = 'deleted' where status = 'deleting' and type = 'Git'";
my $sth_delete = $dbh->prepare($sql_delete);
$sth_delete->execute or die "SQL Error: $DBI::errstr\n";

$dbh->disconnect;
