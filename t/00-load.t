#!perl -T

use Test::More tests => 1;

BEGIN {
	use_ok( 'Acme::Lou' );
}

diag( "Testing Acme::Lou $Acme::Lou::VERSION, Perl $], $^X" );
