package DBH;


use DBIx;

$DBIx::DBH = DBI->connect('dbi:Pg:dbname=mydb', 'postgres', '');

1;

