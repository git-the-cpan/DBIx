use strict;
use Test;

BEGIN { plan tests => 1 }

use DBH;
#use PApp::SQL;
use DBIx;

my $create_db =<<EOS;
CREATE table weather__temp (
	city 	varchar(80),
	temp_lo integer,
	temp_hi	integer,
	prcp 	float,
	date	date
	);
EOS

my $sth = sql_do $create_db;

ok($sth);

