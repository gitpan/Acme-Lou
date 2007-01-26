package Acme::Lou;
use strict;
our $VERSION = '0.01';

use utf8;
use Carp;
use DB_File;
use Encode;
use HTML::Parser;
use MeCab;
use Acme::Lou::Effect;

sub new {
    my $class = shift;
    my $opt   = ref $_[0] eq 'HASH' ? shift : { @_ };
    
    $opt = {
        mecab_charset => 'euc-jp',
        mecab_option  => [],
        dbpath => do {
            my $file = $INC{ join '/', split '::', "$class.pm" };    
            $file =~ s{\.pm$}{/lou-ja2kana.db};
            $file;
        },
        lou_rate => 100,
        is_html => 0,
        html_fx_rate => 0,
        %$opt,
    };
    
    $opt->{dic} ||= do {
        tie(my %db, 'DB_File', $opt->{dbpath}, O_RDONLY) 
          or croak "Can't open $opt->{dbpath}: $!";
        \%db;
    };
    
    $opt->{mecab} 
        ||= new MeCab::Tagger(@{ $opt->{mecab_option} });
     
    bless $opt, $class;
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
        lou_rate => $self->{lou_rate},
        is_html => $self->{is_html},
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
    '連体詞-*' => '',
    '動詞-仮定形' => 'すれ',
    '動詞-仮定縮約１' => 'すれ',
    '動詞-基本形' => 'する',
    '動詞-連用形' => 'し',
    '動詞-体言接続' => 'する',
    '動詞-体言接続特殊２' => 'す',
    '動詞-文語基本形' => 'する',
    '動詞-未然レル接続' => 'せ',
    '動詞-命令ｅ' => '',     
    '動詞-命令ｙｏ' => '',     
    '形容詞-仮定形' => 'だとしたなら',
    '形容詞-仮定縮約１' => 'だとしたなら',
    '形容詞-仮定縮約２' => 'だとしたなら',
    '形容詞-基本形' => 'な',
    '形容詞-体言接続' => 'な',
    '形容詞-文語基本形' => '',
    '形容詞-未然ウ接続' => 'らしかろ',
    '形容詞-未然ヌ接続' => 'らしから',
    '形容詞-命令ｅ' => 'であれ',
    '形容詞-連用ゴザイ接続' => '',
    '形容詞-連用タ接続' => 'だっ',
    '形容詞-連用テ接続' => 'っぽく',
    '形容詞-ガル接続' => '',
);

sub lou {
    my ($self, $text, $opt) = @_;

    # tricks for mecab... Umm.. Do you have any good idea ?
    $text =~ s/\r?\n/\r/g; # need \r
    $text =~ s/ /\x{25a1}/g;
    
    $text = encode($self->{mecab_charset}, $text);
    my @out;
    my $node = $self->{mecab}->parseToNode($text);
    while ($node = $node->{next}) {
        
        my $n = $self->get_node($node); 
        $n->{to} = $self->dic($n->{original});
        $n->{cform} = $cform{"$n->{class}-$n->{type}"}; 
        
        if ($n->{to} =~ /・.+?・/) {
            $n->{to} = "" if int(rand 3);
        }
        if ($n->{to} && defined $n->{cform} && 
            int(rand 100) < $opt->{lou_rate} 
        ) {
            if ($n->{prev}{class} eq '接頭詞' && 
                $n->{prev}{original} =~ /^ご|お$/) {
                pop @out;
            }
            if (int(rand 100) < $opt->{html_fx_rate}) {
                push @out, Acme::Lou::Effect::html_fx($n->{to}).$n->{cform};
            } else {
                push @out, $n->{to}.$n->{cform};
            }
        } else {
            push @out, $n->{surface};
        }
    }
    
    $text = join "", @out;
    $text =~ s/\r/\n/g;
    $text =~ s/\x{25a1}/ /g;
    $text;
}

sub get_node {
    my ($self, $node) = @_;
    my $charset = $self->{mecab_charset};
    
    my $getf = sub {
        my $csv = shift;
        my %f; 
        @f{qw( class class2 class3 class4 form type original yomi pron )} 
            = split ",", $csv;
        return \%f;
    };
    
    my $n = $getf->(decode($charset, $node->{feature}));
    $n->{surface} = decode($charset, $node->{surface});
    $n->{surface} = "" if !defined $n->{surface};
    
    $n->{prev} =  $getf->(decode($charset, $node->{prev}{feature}));
    $n->{prev}{surface} = decode($charset, $node->{prev}{surface});
    
    $n; 
}

sub html_parse {
    my ($self, $html, $opt) = @_;
    my $return = "";
    my %in;
    my $p = new HTML::Parser(
        default_h => [ reverse  
            'text,tagname,event' => sub {
                my ($text, $tag, $event) = @_;
                $return .= $text;
                $tag ||= '';
                $in{$tag}++ if $event eq 'start';
                $in{$tag}-- if $event eq 'end';
            },
        ],
        text_h => [ reverse
            'text' => sub { 
                my ($text) = @_;
                if ($in{script} || $in{style}) {
                    $return .= $text;
                    return;
                }
                $return .= $self->lou($text, {
                    lou_rate => $opt->{lou_rate},
                    html_fx_rate => $in{title} ? 0 : $opt->{html_fx_rate},
                }); 
            },
        ],
    );
    
    chomp $html;
    $p->parse("$html\n");
    
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

=head1 DESCRIPTION

Mr. Lou Ohshiba is a Japanese comedian. This module translates 
text/HTML into his style. 

=head1 METHODS

=over 4

=item $lou = Acme::Lou->new([ \%options ])

=item $lou = Acme::Lou->new([ %options ]) 

Creates an Acme::Lou object.

I<%options> can take...

=over 2

=item * mecab_charset 

Your MeCab dictionary charset. Default is C<euc-jp>. If you compiled 
mecab with utf-8,

    my $lou = new Acme::Lou({ mecab_charset => 'utf-8' });

=item * mecab_option

Optional. Arguments for MeCab::Tagger instance.

    my $lou = new Acme::Lou({ 
        mecab_option => ["-d /path/to/yourdic"],
    });

=item * mecab

You can set your own MeCab::Tagger instance, if you want. Optional. 

=item * lou_rate

=item * is_html 

=item * html_fx_rate

These are global options for C<< $lou->translate() >> (See below).
Default is 

    lou_rate: 100
    is_html: 0
    html_fx_rate: 0

=back

=item $lou->translate($text [, \%options ])

Return translated text in Lou Ohshiba style. C<translate()> expect 
utf-8 byte or utf8 flagged text, and it return utf-8 flaged text.

I<%options>: (overwrite global options)

=over 2

=item * lou_rate

Set percentage of translating. 100 means full translating, 
0 means do nothing.

=item * is_html

If $text is a HTML, you should set true. Acme::Lou makes a fine job 
with HTML::Parser. Default is false. 

=item * html_fx_rate

Set percentage of HTML style decoration. Default is 0. 
When C<html_fx_rate> is set, using HTML::Parser automatically.
(not need to set C<is_html>)

    my $html = <<'HTML';
    <html>
    <body>
    今年もよろしくお願いいたします
    </body>
    </html>
    HTML
    ;
    
    $html = $lou->translate($html, {
        lou_rate => 100,
        html_fx_rate => 50,
    });
    
    # <html>
    # <body>
    # <FONT color=#003399 size=5>ディスイヤー</FONT>もよろしくプリーズいたします
    # </body>
    # </html>

=back

=back

=head1 AUTHOR

Naoki Tomita E<lt>tomita@cpan.orgE<gt>

Special thanks to Taku Kudo

=head1 LICENSE

This program is released under the following license: GPL

=head1 SEE ALSO

L<http://e8y.net/blog/2006/12/31/p139.html>, 
L<http://mecab.sourceforge.jp/>

=cut
