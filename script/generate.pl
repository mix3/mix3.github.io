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
use YAML::Tiny;
use FindBin;

my $resource_dir = dir($FindBin::Bin.'/../resource');

my $metadata_file = file($FindBin::Bin.'/metadata');
my $metadata = $metadata_file->stat ? YAML::Tiny::Load(encode_utf8($metadata_file->slurp)) : YAML::Tiny->new->[0];

my $list = [];

{
    # create, update
    while (my $resource = $resource_dir->next) {
        next if ($resource->is_dir);
        my $id = md5_hex(basename($resource->basename, '.md'));
        push @$list, $id;
        my ($title) = ($resource->openr->getline =~ /^# (.*?)$/);
        my $param = {
            title => $title,
            created_at => $resource->stat->[9],
            updated_at => $resource->stat->[9],
        };
        if ($metadata->{$id}) {
            next if((!$ARGV[0] || $ARGV[0] ne '-f') && $param->{updated_at} == $metadata->{$id}->{updated_at});
            # update
            my $old_param = $metadata->{$id};
            $param->{created_at} = $old_param->{created_at};
            if ($old_param->{title} ne $param->{title}) {
                print 'update: '.$id.' '.$old_param->{title}.' => '.$param->{title}."\n";
            } else {
                print 'update: '.$id."\n";
            }
        } else {
            # create
            print 'create: '.$id."\n"
        }
        $metadata->{$id} = $param;

        &create_article(file($FindBin::Bin.'/../article/'.$id.'.html'), $resource, $param);
    }
}

{
    # delete
    my $article_dir = dir($FindBin::Bin.'/../article');
    while (my $article = $article_dir->next) {
        next if ($article->is_dir);
        my $del = 1;
        for (@$list) {
            if ($_.'.html' eq $article->basename) {
                $del = 0;
                last;
            }
        }
        if ($del) {
            my $id = basename($article->basename, '.html');
            print 'delete: '.$id."\n";
            delete $metadata->{$id};
            $article->remove();
        }
    }
}

{
    my $list = [];
    for my $id (keys %$metadata) {
        push @$list, {
            id         => $id,
            title      => $metadata->{$id}->{title},
            created_at => $metadata->{$id}->{created_at}
        };
    }
    my @result = sort{ $b->{created_at} <=> $a->{created_at} } @$list;

    my $content = '<ol>'."\n";
    for (@result) {
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

my $metadata_fh = $metadata_file->openw;
$metadata_fh->print(YAML::Tiny::Dump($metadata));
$metadata_fh->close;

sub mtime2date {
    return DateTime->from_epoch( epoch => shift )->set_time_zone('Asia/Tokyo');
}

sub create_article {
    my $article  = shift;
    my $resource = shift;
    my $param    = shift;

    my $title = $param->{title};

    my $content = $resource->slurp;
    my $template = encode_utf8(get_data_section('article.html'));
    $content  = markdown($content);
    $template =~ s/#TITLE#/$title/;
    $template =~ s/#CONTENT#/$content/;
    my $fh = $article->openw();
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
