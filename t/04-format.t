use strict;
use Test::Base;

use utf8;
use Acme::Lou;

my $lou = new Acme::Lou;

sub translate {
    my $text = shift;
    my $format = filter_arguments;
    $lou->translate($text, { format => $format });
}

run_compare;

__DATA__
=== ruby 
--- input translate=<ruby><rb>%s</rb><rp>（</rp><rt>%s</rt><rp>）</rp></ruby>
死んでお詫び、などと気のいい事は言って居られぬ。
私は、信頼に報いなければならぬ。
いまはただその一事だ。
走れ！　メロス
--- expected
死んで<ruby><rb>アポロジー</rb><rp>（</rp><rt>お詫び</rt><rp>）</rp></ruby>、などと気のいい事は言って居られぬ。
私は、<ruby><rb>トラスト</rb><rp>（</rp><rt>信頼</rt><rp>）</rp></ruby>に報いなければならぬ。
いまはただその<ruby><rb>ワンシング</rb><rp>（</rp><rt>一事</rt><rp>）</rp></ruby>だ。
<ruby><rb>ラン</rb><rp>（</rp><rt>走れ</rt><rp>）</rp></ruby>！　メロス

