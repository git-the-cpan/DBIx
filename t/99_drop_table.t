use strict;
use Test;

BEGIN { plan tests => 1 }

use DBH;
use PApp::SQL;

sql_exec 'drop table weather__temp';

ok(1);
