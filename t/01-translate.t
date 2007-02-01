use strict;
use Test::Base;

use utf8;
use Acme::Lou;

my $lou = new Acme::Lou;

sub translate {
    my $text = shift;
    my $rate = filter_arguments;
    $lou->translate($text, { lou_rate => $rate });
}

run_compare;

__DATA__
=== basic 
--- input translate=100
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
--- input translate=0
今年もよろしくお願いいたします。
--- expected 
今年もよろしくお願いいたします。

=== adnominal 
--- input translate=100
それ、どんな返事？
--- expected
それ、ホワットリプライ？

=== verb 5-dan
--- input translate=100
変わらない。変わります。変わる。
変わる時、変われば、変わろう。変われ。
--- expected
変わらない。チェンジします。チェンジする。
チェンジする時、チェンジすれば、変わろう。チェンジ。

=== verb kami-1
--- input translate=100
閉じない。いや、閉じます。閉じる。
閉じるとき、閉じれば閉じよ！
--- expected
閉じない。いや、クローズします。クローズする。
クローズするとき、クローズすればクローズ！

=== verb shimo-1
--- input translate=100
調べない。かなり激しく調べます。
調べる。調べるとき調べれば調べろ！
--- expedted
調べない。かなりヴァイオレントっぽくチェックアップします。
チェックアップする。チェックアップするとき、チェックアップすればチェックアップ！

=== adj
--- input translate=100
忙しければ忙しい時忙しかったなら忙しかろう。
忙しく忙しいと、忙しいかわからない。
--- expected
ビジーならばビジーな時ビジーだったならビジーだろう。
ビジーっぽくビジーと、ビジーかわからない。

=== adj2
--- input translate=100
同じなら同じだって同じで同じだろ。
同じな同じに、同じだ。
--- expected
セイムならセイムだってセイムでセイムだろ。
セイムなセイムに、セイムだ。

=== prefix fix
--- input translate=100
お時間をありがとうございます。
ご自慢の御子息。
--- expected 
タイムをありがとうございます。
プライドのサン。

=== adj-basic cform fix
--- input translate=100
日本の女性は美しい。
--- expected 
ジャパンのウーマンはビューティフル。

=== original rule for exclamation and conjunction
--- input translate=100
けれども彼は宣言した。「はい。そうです。」
--- expected
But彼は宣言した。「Yes。そうです。」

