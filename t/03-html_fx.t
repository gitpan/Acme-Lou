use strict;
use Test::Base;

use utf8;
use Acme::Lou;

my $lou = new Acme::Lou;

sub translate {
    my $text = shift;
    $lou->translate($text, { 
        lou_rate => 100,
        html_fx_rate => 100,
    });
}

run_compare;

__DATA__
=== basic 
--- input translate
<html>
<body>今日は暖かい。</body>
</html>
--- expected eval 
qr{^<html>
<body><FONT.*?>トゥデイ<.*?/FONT>は<FONT.*?>ウォーム<.*?/FONT>。</body>
</html>$}

=== like text
--- input translate
今年もよろしくお願いいたします。
ルーと一緒です。

美しい国づくりの礎を築くことができたと、
考えています。
--- expected eval 
qr{^<FONT.*?>ディスイヤー<.*?/FONT>もよろしく<FONT.*?>プリーズ<.*?/FONT>いたします。
ルーと<FONT.*?>トゥギャザー<.*?/FONT>です。

<FONT.*?>ビューティフル<.*?/FONT>な国づくりの礎を<FONT.*?>ビルド<.*?/FONT>することができたと、
<FONT.*?>シンクアバウト<.*?/FONT>しています。$}

=== skip title
--- input translate
<html>
<head>
<title>内緒</title>
<style type="text/css">
/* 内緒 */
body {
    margin: 10px 20px;
}
</style>
</head>
<body>
<div title="内緒">内緒</div>。
<script type="text/javascript">
alert("内緒");
</script>
</body>
</html>
--- expected eval
qr|^<html>
<head>
<title>シークレット</title>
<style type="text/css">
/\* 内緒 \*/
body {
    margin: 10px 20px;
}
</style>
</head>
<body>
<div title="内緒"><FONT.*?>シークレット<.*?/FONT></div>。
<script type="text/javascript">
alert\("内緒"\);
</script>
</body>
</html>$|

