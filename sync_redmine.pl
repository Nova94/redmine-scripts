#!/usr/bin/env perl

use strict;
use warnings;

use cat::db;
use cat::log;

use YAML qw(LoadFile);
use feature qw( switch );


my $config = LoadFile('config.yaml');
my $dbh = connectToDb('gitolite');
my $dbh_redmine = connectToDb('redmine');

my $sql = "select * from projects where status=? and type !=?";
my $sth = $dbh->prepare($sql);

$sth->execute('pending', 'none') or die "SQL Error: $DBI::errstr\n";

while ( my $row = $sth->fetchrow_hashref )
    {
      assocRepository($row)
    }

$dbh->disconnect;

sub assocRepository {
  my ($row) = @_;
  my $projectId  = $row->{'identifier'};
  my $requestor  = $row->{'requestor'};
  my $identifier = getIdentifier($projectId);
  my $type       = $row->{'type'};
  my $repotype   = repoToRedmine($type);
  my $url        = repopath($repotype, $projectId, $identifier, $requestor);
  my $root_url   = repopath($repotype, $projectId, $identifier, $requestor);

  if ( checkRepo($projectId, $identifier) == 0 and ( repoExist($root_url) == 0 ) )
  {
    my $update_sql = "insert into repositories (url, root_url, type, project_id, identifier, is_default) VALUES (?, ?, ?, ?, ?, ?)";
    if (defined $projectId) {
      given ($type) {
        when ('Svn') {
          # This is so that the projects website can access the repos
          # We don't need to do this for git since that is handled by the
          # gitolite umask option
          system("chmod -R g+rwX $url");
        }
        when ('Git') {
          # projects complains if the repo is empty
          chdir $config->{'gitolite_tmpclonedir'};
          system("git clone gitolite@localhost:$requestor-$identifer");
          chdir $config->{'gitolite_tmpclonedir'} . $requestor . "-" . $identifier;
          system("cp $config->{'git_readme'} .");
          system("git add .");
          system("git commit -m \"Initial commit\"");
          system("git push origin master");
          chdir $config->{'gitolite_tmpclonedir'};
          system("rm -r $requestor-$identifier");
          chdir $config->{'redmine_scripts_path'};
        }
        default {
          #We should never get to this case
          errorlog('assocRepository()', "Unsupported type $type");
          die "Unsupported type $type in assocRepository function";
        }
      }

      my $update_stmt = $dbh_redmine->prepare($update_sql);
      given ($type) {
        when ('Svn') {
          $update_stmt->execute("file://" . $url, "file://" . $root_url, $repotype, $projectId, $identifier, "1") or die "SQL Error: $DBI::errstr\n";
        }
        when ('Git') {
          $update_stmt->execute($url, $root_url, $repotype, $projectId, $identifier, "1") or die "SQL Error: $DBI::errstr\n";
        }
        default {
          #We should never get to this case
          errorlog('assocRepository()', "Unsupported type $type");
          die "Unsupported type $type in assocRepository function";
        }
      }

      log('assocRepository()', "Associated project $identifier to repo");
    }
    else {
      errorlog('assocRepository()', "Null value $identifier");
    }
  }
}

sub repoExist {
  my ($root_url) = @_;

  if ( -d $root_url) {
    return 0;
  }
  else {
    errorlog('repoExist()', "Repository does not exist on disk, $root_url dir not found");
    return 1;
  }

}

sub checkRepo {
  my ($projectId, $identifier) = @_;
  my $dbh = connectToDb('redmine');
  my $sql = 'select count(*) as count from repositories where project_id=? and identifier=?';
  my $sth = $dbh->prepare($sql);
  $sth->execute($projectId,$identifier) or die "SQL Error: $DBI::errstr\n";
  my $count = $sth->fetchrow_hashref;
  $sth->finish;
  $dbh->disconnect;

  if ( $count->{'count'} > 0 ) {
    return 1;
  }
  else {
    return 0;
  }
}

# FIXME: Project ID should be available in the database rather than looking it up
# to support multiple repositories
sub getIdentifier {
  my ($projectId) = @_;

  my $dbh = connectToDb('redmine');
  my $sql = 'select name from projects where id=? and name is not null';
  my $sth = $dbh->prepare($sql);
  $sth->execute($projectId) or die "SQL Error: $DBI::errstr\n";
  my $row = $sth->fetchrow_hashref;
  my $identifier =  $row->{'name'};
  $sth->finish;
  $dbh->disconnect;
  return $identifier;
}

sub repoToRedmine {
  my ($type) = @_;

  given ($type) {
    when ('Svn') {
      return 'Repository::Subversion';
    }
    when ('Git') {
      return 'Repository::Git';
    }
    default {
      errorlog('repoToRedmine()', "Unsupported type $type");
      die "Unsupported type $type in repo_to_redmine function";
    }
  }
}

sub repopath {
  my ($repotype, $projectId, $identifier, $requestor) = @_;

  given ($repotype) {
    when ('Repository::Subversion') {
      return $config->{'svn_root'} . "$projectId";
    }
    when ('Repository::Git') {
      return $config->{'git_root'} . "$requestor-$identifier.git";
    }
    default {
      errorlog('repopath()', "Unsupported type $repotype");
      die "Unsupported type $repotype in repopath function";
    }
  }
}
