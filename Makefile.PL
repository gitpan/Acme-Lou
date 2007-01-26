use strict;
use warnings;
use ExtUtils::MakeMaker;

use DB_File;
use Fatal qw(open close);

my $dicfile = "./lib/Acme/Lou/lou-ja2kana.db";
print "make $dicfile...\n";
tie(my %db, 'DB_File', $dicfile) or die $!;

%db = ();
open my $ja2kana, '<', "./dic/lou-ja2kana.csv" or die $!;
while (<$ja2kana>) {
    chomp;
    next unless $_;
    next if /^#/;
    my ($ja, $kana) = split ',';
    $db{$ja} = $kana;
}
untie %db;


WriteMakefile(
    NAME                => 'Acme::Lou',
    AUTHOR              => 'Naoki Tomita <tomita@cpan.org>',
    VERSION_FROM        => 'lib/Acme/Lou.pm',
    ABSTRACT_FROM       => 'lib/Acme/Lou.pm',
    PL_FILES            => {},
    PREREQ_PM => {
        'Test::More' => 0,
        'Encode' => 0,
        'HTML::Parser' => 0,
        'MeCab' => 0,
    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'Acme-Lou-*' },
);

