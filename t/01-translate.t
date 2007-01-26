use strict;
use Test::Base;

use utf8;
use Acme::Lou;

my $lou = new Acme::Lou;

sub translate {
    my $text = shift;
    my @rate = split ",", filter_arguments;
    $lou->translate($text, { 
        lou_rate => $rate[0],
        html_fx_rate => $rate[1],
    });
}

run_compare;

__DATA__
=== 100 percent
--- input translate=100,0
今年もよろしくお願いいたします。
ルーと一緒です。

美しい国づくりの礎を築くことができたと、
考えています。
--- expected 
ディスイヤーもよろしくプリーズいたします。
ルーとトゥギャザーです。

ビューティフルな国づくりの礎をビルドすることができたと、
シンクアバウトしています。

=== 0 percent
--- input translate=0,0
今年もよろしくお願いいたします。
ルーと一緒です。

美しい国づくりの礎を築くことができたと、
考えています。
--- expected 
今年もよろしくお願いいたします。
ルーと一緒です。

美しい国づくりの礎を築くことができたと、
考えています。

=== html_fx
--- input translate=100,100
今年もよろしくお願いいたします。
ルーと一緒です。

美しい国づくりの礎を築くことができたと、
考えています。
--- expected eval 
qr{
^
<FONT.*?>ディスイヤー<.*?/FONT>もよろしく<FONT.*?>プリーズ<.*?/FONT>いたします。\n
ルーと<FONT.*?>トゥギャザー<.*?/FONT>です。\n
\n
<FONT.*?>ビューティフル<.*?/FONT>な国づくりの礎を<FONT.*?>ビルド<.*?/FONT>することができたと、\n
<FONT.*?>シンクアバウト<.*?/FONT>しています。
$
}x

