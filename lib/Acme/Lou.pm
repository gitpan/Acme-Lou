package Acme::Lou;
use strict;
our $VERSION = '0.03';

use utf8;
use Acme::Lou::Effect;
use Carp;
use DB_File;
use Encode;
use HTML::Parser;
use Text::MeCab;

sub new {
    my $class = shift;
    my $opt   = ref $_[0] eq 'HASH' ? shift : { @_ };
    
    my %self = (
        mecab_charset => 'euc-jp',
        mecab_option  => {},
        dbpath => do {
            my $file = $INC{ join '/', split '::', "$class.pm" };    
            $file =~ s{\.pm$}{/lou-ja2kana.db};
            $file;
        },
        format       => '%s',
        is_html      => 0,
        lou_rate     => 100,
        html_fx_rate => 0,
        %$opt,
    );
    
    $self{dic} ||= do {
        tie(my %db, 'DB_File', $self{dbpath}, O_RDONLY) 
          or croak "Can't open $self{dbpath}: $!";
        \%db;
    };
    
    $self{mecab} ||= new Text::MeCab($self{mecab_option});
     
    bless \%self, $class;
}

sub mecab {
    shift->{mecab};
}

sub dic {
    my ($self, $word) = @_;
    utf8::encode($word) if utf8::is_utf8($word);
    decode('utf8', $self->{dic}->{$word} || "");
}

sub translate {
    my ($self, $text, $opt) = @_;
    return "" unless $text;
    utf8::decode($text) unless utf8::is_utf8($text);
    
    $opt = {
        format       => $self->{format},
        is_html      => $self->{is_html},
        lou_rate     => $self->{lou_rate},
        html_fx_rate => $self->{html_fx_rate},
        %{ $opt || {} },
    };

    if (!$opt->{lou_rate}) {
        return $text;
    } elsif ($opt->{is_html} || $opt->{html_fx_rate}) {
        return $self->html_parse($text, $opt);
    } else {
        return $self->lou($text, $opt);
    }
}

our %cform = (
    '名詞-*' => '',
    '感動詞-*' => '',
    '接続詞-*' => '',
    '連体詞-*' => '',
    '動詞-仮定形' => 'すれ',
    '動詞-仮定縮約１' => 'すれ',
    '動詞-基本形' => 'する',
    '動詞-体言接続' => 'する',
    '動詞-体言接続特殊２' => 'す',
    '動詞-文語基本形' => 'する',
    '動詞-未然レル接続' => 'せ',
   #'動詞-未然形' => '',
   #'動詞-未然特殊'
    '動詞-命令ｅ' => '',     
    '動詞-命令ｒｏ' => '',     
    '動詞-命令ｙｏ' => '',     
   #'動詞-連用タ接続' => '',
    '形容詞-ガル接続' => '',
    '動詞-連用形' => 'し',
    '形容詞-仮定形' => 'なら',
    '形容詞-仮定縮約１' => 'なら',
    '形容詞-仮定縮約２' => 'なら',
    '形容詞-基本形' => 'な',
    '形容詞-体言接続' => 'な',
    '形容詞-文語基本形' => '',
    '形容詞-未然ウ接続' => 'だろ',
    '形容詞-未然ヌ接続' => 'らしから',
    '形容詞-命令ｅ' => 'であれ',
    '形容詞-連用ゴザイ接続' => '',
    '形容詞-連用タ接続' => 'だっ',
    '形容詞-連用テ接続' => 'っぽく',
);

sub lou {
    my ($self, $text, $opt) = @_;

    # tricks for mecab... Umm.. Do you have any good idea ?
    $text =~ s/\r?\n/\r/g; # need \r
    $text =~ s/ /\x{25a1}/g; # white space to "tofu"
    
    $text = encode($self->{mecab_charset}, $text);
    my @out;
    my $node = $self->mecab->parse($text);
    while ($node = $node->next) {
        
        my $n = $self->decode_node($node); 
        $n->{to} = $self->dic($n->{original});
        $n->{class_type} = "$n->{class}-$n->{type}"; 
        $n->{cform} = $cform{ $n->{class_type} }; 
        
        if ($n->{to} =~ s/\s//g >= 2) {
            $n->{to} = "" if int(rand 3); # idiom in over 3 words.
        }
        if ($n->{class} =~ /接続詞|感動詞/) { # only "But" "Yes",... 
            $n->{to} = "" if $n->{to} !~ /^[a-z]+$/i;
        }
        
        if ($n->{to} && defined $n->{cform} && 
            length $n->{original} > 1 &&
            int(rand 100) < $opt->{lou_rate} 
        ) {
            if ($n->{prev}{class} eq '接頭詞' && 
                $n->{prev}{original} =~ /^[ごお御]$/) {
                pop @out;
            }
            if ($n->{class_type} eq '形容詞-基本形' && 
                $n->{next}{class} =~ /助詞|記号/) {
                $n->{cform} = "";
            }
            
            $n->{to} = Acme::Lou::Effect::html_fx($n->{to})
                if int(rand 100) < $opt->{html_fx_rate};
            $n->{to} .= $n->{cform};

            push @out, sprintf($opt->{format}, $n->{to}, $n->{surface});
        } else {
            push @out, $n->{surface};
        }
    }
    $text = join "", @out;
    $text =~ s/\r/\n/g;
    $text =~ s/\x{25a1}/ /g;
    $text;
}

sub decode_node {
    my ($self, $node) = @_;
    my $charset = $self->{mecab_charset};
    
    my $getf = sub {
        my $csv = shift;
        my %f; 
        @f{qw( class class2 class3 class4 form type original yomi pron )} 
            = split ",", $csv;
        return \%f;
    };
     
    my $n = $getf->(decode($charset, $node->feature));
    $n->{surface} = decode($charset, $node->surface);
    $n->{surface} = "" if !defined $n->{surface};
    
    for (qw( prev next )) {
        next unless $node->$_;
        $n->{$_} =  $getf->(decode($charset, $node->$_->feature));
        $n->{$_}{surface} = decode($charset, $node->$_->surface);
    }
    
    $n; 
}

sub html_parse {
    my ($self, $html, $opt) = @_;
    my $return = "";
    
    my $p = new HTML::Parser( api_version => 3 );
    my %in;
    
    $p->handler( default => reverse 
        'text,tagname,event' => sub {
            my ($text, $tag, $event) = @_;
            $return .= $text;
            $tag ||= '';
            $in{$tag}++ if $event eq 'start';
            $in{$tag}-- if $event eq 'end';
        }
    );
    
    $p->handler( text => reverse 
        'text' => sub {
            my ($text) = @_;
            if ($in{script} || $in{style}) {
                $return .= $text;
                return;
            }
            $return .= $self->lou($text, {
                format       => $opt->{format},
                lou_rate     => $opt->{lou_rate},
                html_fx_rate => $in{title} ? 0 : $opt->{html_fx_rate},
            });
        }
    );
     
    chomp $html;
    $p->parse("$html\n") or croak "Parser failed. $!";
    $p->eof;
     
    $return;
}

1;
__END__

=encoding utf-8

=head1 NAME

Acme::Lou - Let's together with Lou Ohshiba 

=head1 SYNOPSIS

    use utf8;
    use Acme::Lou;
    
    my $lou = new Acme::Lou;
    
    my $text = "「美しい国、日本」";
    print $lou->translate($text); # 「ビューティフルな国、ジャパン」

    print $lou->translate($text, {
        lou_rate     =>  50,
        html_fx_rate => 100,
    })
    # 「美しい国、<FONT color=#003399>ジャパン</FONT>」

=head1 DESCRIPTION

Mr. Lou Ohshiba is a Japanese comedian. This module translates 
text or HTML into his style. 

=head1 METHODS

=over 4

=item $lou = Acme::Lou->new([ \%options ])

=item $lou = Acme::Lou->new([ %options ]) 

Creates an Acme::Lou object.

I<%options> can take...

=over 4 

=item * mecab_charset 

Your MeCab dictionary charset. Default is C<euc-jp>. If you compiled 
mecab with C<utf-8>,

    my $lou = new Acme::Lou( mecab_charset => 'utf-8' );

=item * mecab_option

Optional. Arguments for L<Text::MeCab> instance.

    my $lou = new Acme::Lou({ 
        mecab_option => { dicdir => "/path/to/yourdicdir" },
    });

=item * mecab

You can set your own Text::MeCab instance, if you want. Optional. 

=item * format

=item * is_html 

=item * lou_rate

=item * html_fx_rate

These are global options for C<< $lou->translate() >> (See below).

Defaults are 

    format       => '%s',
    is_html      => 0,
    lou_rate     => 100,
    html_fx_rate => 0,

=back

=item $lou->translate($text [, \%options ])

Return translated text in Lou Ohshiba style. C<translate()> expect 
utf-8 byte or utf-8 flagged text, and it return utf-8 flaged text.

I<%options>: (overwrite global options)

=over 4

=item * format 

Output format string for C<sprintf>. Default is C<%s>.
It is taken as follows. 

    sprintf(C<format>, "translated word", "original word")

e.g.
    
    Default:
    $lou->translate("考えておく");
    # シンクアバウトしておく
     
    Idea 1: <ruby> tag
    $lou->translate("考えておく", { 
        format => '<ruby><rb>%s</rb><rp>(</rp><rt>%s</rt><rp>)</rp></ruby>',
    });
    # <ruby><rb>シンクアバウトし</rb><rp>(</rp><rt>考え</rt><rp>)</rp></ruby>ておく
     
    Idea 2: for English study (?!)
    $lou->translate("考えておく", { 
        format => '%2$s[%1$s]', # require perl v5.8
    });
    # 考え[シンクアバウトし]ておく

C<format> option was added by version 0.03.

=item * is_html

Optional. If $text is a HTML, you should set true. Acme::Lou makes 
a fine job with HTML::Parser mode. Default is false. 

=item * lou_rate

Set percentage of translating. 100 means full translating, 
0 means do nothing.

=item * html_fx_rate

Set percentage of HTML style decoration. Default is 0. 
When C<html_fx_rate> is set, using HTML::Parser automatically.
(don't need to set C<is_html>)

=back

If using HTML::Parser, C<translate()> skips the text in C<< <script> >> 
and C<< <style> >> tag and attribute values.

And, C<html_fx_rate> skips the text in C<< <title> >> tag.

    my $html = <<'HTML';
    <html>
    <head>新年のごあいさつ</head>
    <body>
    <img src="foo.jpg" alt="新年" />
    今年もよろしく
    お願いいたします。
    </body>
    </html>
    HTML
    ;
     
    print $lou->translate($html, {
        lou_rate => 100, # translate all words that Acme::Lou knows.
        html_fx_rate => 100, # and decorate all words.
    });
      
    # <html>
    # <head>ニューイヤーのごあいさつ</head>
    # <body>
    # <img src="foo.jpg" alt="新年" />
    # <FONT color=#0000ff size=5>ディスイヤー</FONT>もよろしく
    # <FONT color=#df0029 size=6><STRONG>プリーズ</STRONG></FONT>いたします
    # </body>
    # </html>

HTML is not broken.

=back

=head1 AUTHOR

Naoki Tomita E<lt>tomita@cpan.orgE<gt>

Special thanks to Taku Kudo

=head1 LICENSE

This program is released under the following license: GPL

=head1 SEE ALSO

L<http://e8y.net/labs/lou_trans/>, L<http://mecab.sourceforge.jp/>, 
L<Text::MeCab>

=cut
