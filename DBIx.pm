package DBIx;

require 5.005_62;
use strict;
use warnings;

use Carp qw(confess cluck);
use DBI;
use POSIX qw(strftime);


require Exporter;

our @ISA = qw(Exporter);

# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.

# This allows declaration	use DBIx ':all';
# If you do not need this, moving things directly into @EXPORT or @EXPORT_OK
# will save memory.
our %EXPORT_TAGS = ( 'all' => [ qw(
	
				  ) ] );

our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );

our @EXPORT = qw(
		 sql_do one_col one_row one_row_href
		 all_rows all_rows_href
		 sql_date sql_date_from_href
		 begin_transaction
		 commit_transaction
		 rollback_transaction
		 hung_transactions
		);
our $VERSION = '0.02';


# Preloaded methods go here.

###############################
# Utility SQL executing methods
###############################

sub gen_error_text {
    use Data::Dumper;
    Dumper(\@_);
}

sub get_dbh {
  my $caller_pkg = shift;

  my $dollar = chr 36;		# done to allow cperl-mode highlighting to work

  my @DBH =
    map { sprintf "%s%s::DBH", $dollar, $_ } (__PACKAGE__, $caller_pkg) ;

  my $dbh;
  for (@DBH) {
    if (eval "defined($_) and ref($_) and $_->isa('DBI::db')") {
      return eval "$_";
    }
  }

  # ack! I think the eval() is mucking it up as well.

  die "No useable dbh discovered in @DBH";
}

sub sql_do {

  @_ >= 1 or cluck "must pass at least 1 argument";

  my ($dbh, $sql, @bind);
  if (ref($_[0])) {
    ($dbh, $sql, @bind) = @_;
  } else {
    ($dbh, $sql, @bind) = (get_dbh(scalar caller), @_);
  }

  my $sth;
  eval
    {
      $sth = $dbh->prepare_cached( $sql );
      $sth->execute(@bind);
    };

  if ($@) {
    cluck gen_error_text($@,@_);
  }

  return $sth;
}

sub all_rows
  {
    my $sth = sql_do(@_);

    my @data;
    eval {
      my @row;
      $sth->bind_columns( \ (@row[ 0..$#{ $sth->{NAME_lc} } ] ) );

      while ( $sth->fetch ) {
	push @data, [@row];
      }

      $sth->finish;
    };
    if ($@) {
      cluck gen_error_text($@,@_);
    }

    return undef unless scalar @data;

    return @data;
  }


sub all_rows_href
  {
    my $sth = sql_do(@_);

    my @data;

    eval {
      my %hash;
      $sth->bind_columns( \ ( @hash{ @{ $sth->{NAME_lc} } } ) );

      while ( $sth->fetch ) {
	push @data, {%hash};
      }

      $sth->finish;
    };
    if ($@) {
      cluck gen_error_text($@,@_);
    }

    scalar @data or return undef;

    return @data;
  }

sub one_row {

  my $sth = sql_do(@_);

  my @row;
  eval {
    @row = $sth->fetchrow_array;
    $sth->finish;
  };
  if ($@) {
    cluck gen_error_text($@,@_);
  }

  (scalar @row) or return undef;

  return wantarray ? @row : $row[0];
}

sub one_row_href
  {
    my $sth = sql_do(@_);

    my %hash;
    eval {
      my @row = $sth->fetchrow_array;
      @hash{ @{ $sth->{NAME_lc} } } = @row if @row;
      $sth->finish;
    };
    if ($@) {
      cluck gen_error_text($@,@_);
    }
    return undef unless scalar keys %hash;
    return \%hash;
  }

sub one_col  {
    my $sth = sql_do(@_);

    my @data;
    eval {
      my @row;
      $sth->bind_columns( \ (@row[ 0..$#{ $sth->{NAME_lc} } ] ) );

      while ( $sth->fetch ) {
	push @data, $row[0];
      }
      $sth->finish;
    };
    if ($@) {
      cluck gen_error_text($@,@_);
    }

    return undef unless scalar @data;

    return wantarray ? @data : $data[0];
  }

sub sql_date {
  my $time = $_[1] || time;
  return strftime '%Y/%m/%d %H:%M:%S', localtime($time);
}

sub sql_date_from_href {
  my $struct = shift;

  my $date = sprintf("%04d/%02d/%02d",
		     $struct->{year},
		     $struct->{month},
		     $struct->{day},
		    );

  $struct->{hours} ||= 0;
  $struct->{minutes} ||= 0;
  $struct->{seconds} ||= 0;

  $date .= sprintf(" %02d:%02d:%02d",
		   $struct->{hours},
		   $struct->{minutes},
		   $struct->{seconds},
		  );

  return $date;
}


##########################
# Transaction Processing #
##########################

sub begin_transaction {
  my $dbh;
  if (not @_) {
    $dbh = get_dbh(scalar caller);
  } elsif (@_ == 1) {
    $dbh = shift
  } else {
    die "Too many arguments passed (@_). Only 0 or 1 arg allowed.";
  }

  $dbh->{private_tran_count} = 0 unless defined $dbh->{private_tran_count};
  $dbh->{private_tran_count}++;

  $dbh->{AutoCommit} = 0;
}


sub commit_transaction {
  my $dbh;
  if (not @_) {
    $dbh = get_dbh(scalar caller);
  } elsif (@_ == 1) {
    $dbh = shift
  } else {
    die "Too many arguments passed (@_). Only 0 or 1 arg allowed.";
  }

  # More commits than begin_tran.  Not correct.
  unless ( defined $dbh->{private_tran_count} ) {
    my $callee = (caller(1))[3];
    warn "$callee called commit without corresponding begin_tran call\n";
  }

  $dbh->{private_tran_count}--;

  # Don't actually commit to we reach 'uber-commit'
  return if $dbh->{private_tran_count};

  if (!$dbh->{AutoCommit}) {
    $dbh->commit;
  }
  $dbh->{AutoCommit} = 1;

  $dbh->{private_tran_count} = undef;
}

sub rollback_transaction {
  my $dbh;
  if (not @_) {
    $dbh = get_dbh(scalar caller);
  } elsif (@_ == 1) {
    $dbh = shift;
  } else {
    die "Too many arguments passed (@_). Only 0 or 1 arg allowed.";
  }

  if (!$dbh->{AutoCommit}) {
    $dbh->rollback;
  }
  $dbh->{AutoCommit} = 1;

  $dbh->{private_tran_count} = undef;
}

sub hung_transactions {
  my $dbh;
  if (not @_) {
    $dbh = get_dbh(scalar caller);
  } elsif (@_ == 1) {
    $dbh = shift;
  } else {
    die "Too many arguments passed (@_). Only 0 or 1 arg allowed.";
  }

  $dbh->{private_tran_count}
}



1;
__END__
  # Below is stub documentation for your module. You better edit it!

=head1 NAME

DBIx - concise SQL-based DBI usage

=head1 SYNOPSIS

  use DBIx;

 my $col  = one_col       $sql, @bind ;
 my @col  = one_col       $sql, @bind ;
 
 my $row  = one_row       $sql, @bind ;
 my @row  = one_row       $sql, @bind ;
 my $row  = one_row_href  $sql, @bind ;
 
 my @rows = all_rows      $sql, @bind ;
 my @rows = all_rows_href $sql, @bind ;
 
 my $sth  = sql_do        $sql, @bind ;
 
 my $date = sql_date;	# calculated from now
 my $date = sql_date_from_href
  { year   => 1969,
    month  => 5,
    day    => 11,
    hours  => 5,        # defaults to 00 if not specified
    minutes => 12,	# defaults to 00 if not specified
    seconds => 35	# defaults to 00 if not specified
  } ;

 begin_transaction;
  # some SQL activities ...
 commit_transaction;
  # or maybe
 rollback_transaction;

 DESTROY {
  if (my $count = hung_transactions) {
    warn "DBH is going out of scope with unbalanced begin_tran/commit call count of $count";
  }


=head1 DESCRIPTION

DBIx provides a convenient meta-layer for DBI usage. Actually, to be honest
DBIx provides code written by Matt Seargent in the Example::DB::Default of
DBIx::AnyDBD. However, most of that code was of such obvious general utility
that I decided to rip it out and make it generally useful. In doing so, I 
decided to make the passing of a database handle to the API functions 
optional and provide a means of searching for a pre-created handle.
This is an idea borrowed from PApp::SQL, an excellent DBI meta-layer.

The synopsis should make it clear how to use this package. The only
other thing that requires not is that undef is returned when the requested
data cannot be retrieved, e.g:

   my $row  = one_row_href 'SELECT * FROM user WHERE email = ?', $email;
  $row or die "no user has email $email";

Oh and one more thing. I will discuss how database handles are found 
so that the API functions can actually do database work.

=head2 LOOKING UP DATABASE HANDLES

All API functions shown in the SYNOPSIS actually take an argument just 
after the function name which must be a viable DBI database handle.
However, this argument is optional and if it does not exist then a search is
made for a database handle as follows:

=over 4

=item 1 it looks in the current package for a package wariable C<$DBH>

=item 2 it looks in the for a package wariable C<$DBIx::DBH>

=back

Thus the following call: 

 my $col  = one_col       $sql, @bind ;

which performs the documented lookup described above could actually be:

 my $col  = one_col       $dbh, $sql, @bind ;

and eliminate the lookup.


=head2 EXPORT

All the things listed in the SYNOPSIS are exported.


=head1 AUTHOR

T. M. Brannon, <tbone@cpan.org>

Shamelessly stolen from Matt Seargent's Example::DB::Default
code in DBIx::AnyDBD

=head1 SEE ALSO

DBIx::AnyDBD, PApp::SQL, DBIx::Broker, DBIx::Easy, EZDBI,
DBIx::DWIW, DBIx::Abstract, DBIx::AbstractLite, and the DBIx and SQL
hierarchies on http://kobesearch.CPAN.org

=cut
