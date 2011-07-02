#!/usr/bin/env perl

use strict;
use warnings;
use utf8;

use Data::Section::Simple qw/get_data_section/;
use Text::Markdown qw/markdown/;
use Digest::MD5  qw/md5_hex/;
use Path::Class;
use DateTime;
use Encode;
use File::Basename;

use FindBin;

my $resource_dir = dir($FindBin::Bin.'/../resource');

my $list = [];

# create or update
while (my $resource = $resource_dir->next) {
    next if ($resource->is_dir);
    my $title = basename($resource->basename);
    my $id = md5_hex($title);
    push @$list, {title => $title, id => $id};
    my $article = file($FindBin::Bin.'/../article/'.$id.'.html');
    if ($article->stat) {
        next if(($resource->stat->[9] < $article->stat->[9]) && !($ARGV[0] && $ARGV[0] eq '-f'));
        print 'update: '.$title.' '.$id.".html\n";
    } else {
        print 'create: '.$title.' '.$id."\n";
    }
    my @content = $resource->slurp;
    my $content = '';
    for (@content) {
        $content .= $_;
    }
    my $template = encode_utf8(get_data_section('article.html'));
    $content  = markdown($content);
    $template =~ s/#TITLE#/$title/;
    $template =~ s/#CONTENT#/$content/;
    my $fh = $article->openw();
    print $fh $template;
    $fh->close;
}

# delete
{
    my $article_dir = dir($FindBin::Bin.'/../article');
    while (my $article = $article_dir->next) {
        next if ($article->is_dir);
        my $del = 1;
        for (@$list) {
            if ($_->{id}.'.html' eq $article->basename) {
                $del = 0;
                last;
            }
        }
        if ($del) {
            print 'delete: '.$article->basename."\n";
            $article->remove();
        }
    }
}

# index
{
    my $content = '<ol>'."\n";
    for (@$list) {
        $content .= '    <li><a href="/article/'.$_->{id}.'.html">'.$_->{title}.'</a></li>'."\n";
    }
    $content .= '</ol>';
    my $template = encode_utf8(get_data_section('index.html'));
    $template =~ s/#CONTENT#/$content/;
    my $file = file($FindBin::Bin.'/../index.html');
    my $fh = $file->openw();
    print $fh $template;
    $fh->close;
}

__DATA__

@@ index.html
<!doctype html>
<html>
<head>
    <meta charset="utf-8" />
    <title>Markdownブログ</title>
    <script src="/js/jquery-1.6.1.min.js" type="text/javascript"></script>
</head>
<body>
#CONTENT#
</body>
</html>

@@ article.html
<!doctype html>
<html>
<head>
    <meta charset="utf-8" />
    <title>#TITLE#</title>
    <link href="/css/prettify/prettify.css" rel="stylesheet" type="text/css" media="screen" />
    <script src="/js/prettify/prettify.js" type="text/javascript"></script>
    <script src="/js/jquery-1.6.1.min.js" type="text/javascript"></script>
    <script type="text/javascript">
        $(function(){
            $('pre').filter(function(){
                console.log($(this).parent());
                return !$(this).parent().hasClass('gist-highlight');
            }).addClass('prettyprint linenums');
            prettyPrint();
            $('#content').fadeIn(2000);
        });
    </script>
</head>
<body>
<div id="content" style="display:none">
#CONTENT#
</div>
</body>
</html>
