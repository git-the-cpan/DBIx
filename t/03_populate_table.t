use strict;
use Test;

BEGIN { plan tests => 1 }

use DBH;
use DBIx;


=head1

Randomly populate a 5-column table with dummy data

=cut
 

sub letter {
  my $offset = int rand 55;
  my $A = 65;
  chr($A + $offset);
}

sub city   {
  my $chars = 10 + int rand 20;
  my $city;

  $city .= letter for (1..$chars);

  $city;
}

sub temp {
  my $low = int rand 40;
  my $hi  = $low + int rand 40;
  ($low, $hi);
}

sub prcp { rand 1 }

sub date {
  my $year = 1994 + int rand 7;
  my $mon  = sprintf "%02d", 1 + int rand 12;
  my $day  = sprintf "%02d", 1 + int rand 27;
  "$year-$mon-$day";
}


my $insert = 
  'insert into weather__temp(city,temp_lo,temp_hi,prcp,date)
  values(?,?,?,?,?)';


my $count;
my $records = 100;
{
  my @insert = (city,temp,prcp,date);
  sql_do $insert, @insert;

  redo unless ++$count > $records;
}

ok($records);
