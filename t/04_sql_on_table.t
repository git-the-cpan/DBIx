use strict;
use Test;

BEGIN { plan tests => 6 }

use DBH;
use DBIx;

our $table = 'weather__temp';

my $col = one_col "SELECT prcp FROM $table LIMIT 1";

warn "COL: $col";
ok($col);

my @col = one_col "SELECT prcp FROM $table LIMIT 10";

warn "COL: @col";
ok(@col == 10);

my $sql = "SELECT date FROM $table LIMIT 10";

my $col = one_col $sql;

warn "one_col (scalar): $col";

ok($col);

my @col = one_col $sql;

warn "one_col (array): @col";

ok(@col);

my $sql = "SELECT * FROM $table LIMIT 1";

my $row = one_row $sql;
warn "one_row: $row";

my @row = one_row $sql;
warn "one_row: @row";

use Data::Dumper;
my $row = one_row_href $sql;
warn "one_row_href: ", Dumper($row);

my $sql = "SELECT * FROM $table LIMIT 10";

my @rows = all_rows $sql;
warn "all_rows: ", Dumper(\@rows);

my @rows = all_rows_href $sql;
warn "all_rows_href: ", Dumper(\@rows);

my $sql_date = sql_date;
my $sql_date_href = sql_date_from_href { year   => 1969,
      month  => 5,
	day    => 11,
	  hours  => 5,		# defaults to 00 if not specified
	    minutes => 12,	# defaults to 00 if not specified
	      seconds => 35	# defaults to 00 if not specified
	    } ;

warn "sd: $sql_date";
warn "sdh: $sql_date_href";

sub ins {

    my $insert = "INSERT INTO $table(city,temp_lo,temp_hi,date) VALUES ('aa',12,24,'1997-03-27')";
    sql_do $insert;
}

sub check_ins {
    my $one_col = one_col "SELECT city FROM $table WHERE city = 'aa'";
    warn "one_col_post_rollback/commit: $one_col";
    $one_col;
}


begin_transaction;
ins;
rollback_transaction;
ok(undef,check_ins);


begin_transaction;
ins;
commit_transaction;
ok('aa',check_ins);

