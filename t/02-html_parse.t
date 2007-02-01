use strict;
use Test::Base;

use utf8;
use Acme::Lou;

my $lou = new Acme::Lou;

sub translate {
    my $text = shift;
    $lou->translate($text, { is_html => 1 });
}

run_compare;

__DATA__
=== basic 
--- input translate
<html>
<body>今日は暖かい。</body>
</html>
--- expected
<html>
<body>トゥデイはウォーム。</body>
</html>

=== like text
--- input translate
今年もよろしくお願いいたします。
ルーと一緒です。

美しい国づくりの礎を築くことができたと、
考えています。
--- expected 
ディスイヤーもよろしくプリーズいたします。
ルーとトゥギャザーです。

ビューティフルな国づくりの礎をビルドすることができたと、
シンクアバウトしています。

=== skip attrs,style, and script
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
--- expected 
<html>
<head>
<title>シークレット</title>
<style type="text/css">
/* 内緒 */
body {
    margin: 10px 20px;
}
</style>
</head>
<body>
<div title="内緒">シークレット</div>。
<script type="text/javascript">
alert("内緒");
</script>
</body>
</html>
