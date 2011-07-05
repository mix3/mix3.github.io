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
use XML::RSS;
use DateTime::Format::Mail;

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
            resource => $resource->basename,
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
    # index
    my $content = '<ol>'."\n";
    for (&sorted_list($metadata)) {
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

{
    # rss
    my $rss = new XML::RSS (version => '2.0');
    my $i = 0;
    for (&sorted_list($metadata)) {
        if ($i == 0) {
            my $created_at = DateTime::Format::Mail->format_datetime(&mtime2date($_->{created_at}));
            my $builded_at = DateTime::Format::Mail->format_datetime(DateTime->now->set_time_zone('Asia/Tokyo'));
            $rss->channel(
                title => encode_utf8('萌えキャラ的にクリスマスはキリスト教的なイベントだから仏教的人種はスルー的な？みたいな？'),
                link => 'http://mix3.github.com/',
                description => encode_utf8('命名:萌えキャラピュタ'),
                pubDate => $created_at,
                lastBuildDate => $builded_at,
            );
        }
        last if(10 < ++$i);
        my $content = file($FindBin::Bin.'/../resource/'.$_->{resource})->slurp;
        $content = html_escape($content);
        my $created_at = DateTime::Format::Mail->format_datetime(&mtime2date($_->{created_at}));
        $rss->add_item(
            title => $_->{title},
            link => 'http://mix3.github.com/article/'.$_->{id}.'.html',
            description => "\n<![CDATA[\n".$content."]]>\n",
            pubDate => $created_at,
        );
    }
    my $rdf_fh = file($FindBin::Bin.'/../index.rdf')->openw;
    my $data = $rss->as_string;
    $data =~ s/&#x([0-9A-Fa-f]{2});/pack("H2", $1)/eg;
    print $rdf_fh $data;
    $rdf_fh->close;
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

sub sorted_list {
    my $metadata = shift;
    my $list = [];
    for my $id (keys %$metadata) {
        push @$list, {
            id         => $id,
            title      => $metadata->{$id}->{title},
            created_at => $metadata->{$id}->{created_at},
            resource   => $metadata->{$id}->{resource},
        };
    }
    return sort{ $b->{created_at} <=> $a->{created_at} } @$list;
}

sub html_escape {
    my $content = shift;
    my @escape_from = qw(& > < " ');
    my @escape_to = ('&amp;', '&gt;', '&lt;', '&quot;', '&#39;');
    for (my $i = 0; $i <= $#escape_from; $i++) {
        $content =~ s/$escape_from[$i]/$escape_to[$i]/g;
    }
    return $content;
}

__DATA__

@@ index.html
<!doctype html>
<html>
<head>
    <meta charset="utf-8" />
    <title>萌えキャラ的にクリスマスはキリスト教的なイベントだから仏教的人種はスルー的な？みたいな？</title>
    <script src="/js/jquery-1.6.1.min.js" type="text/javascript"></script>
    <link rel="alternate" type="application/rss+xml" title="RSS" href="http://mix3.github.com/index.rdf" />

<script type="text/javascript">

  var _gaq = _gaq || [];
  _gaq.push(['_setAccount', 'UA-10744212-4']);
  _gaq.push(['_setDomainName', 'github.com']);
  _gaq.push(['_setAllowHash', 'false']);
  _gaq.push(['_trackPageview']);

  (function() {
    var ga = document.createElement('script'); ga.type = 'text/javascript'; ga.async = true;
    ga.src = ('https:' == document.location.protocol ? 'https://ssl' : 'http://www') + '.google-analytics.com/ga.js';
    var s = document.getElementsByTagName('script')[0]; s.parentNode.insertBefore(ga, s);
  })();

</script>

</head>
<body>
#CONTENT#
<!-- X:S ZenBackWidget --><script type="text/javascript">document.write(unescape("%3Cscript")+" src='http://widget.zenback.jp/?base_uri=http%3A//mix3.github.com&nsid=96368406281861426%3A%3A97485858524947259&rand="+Math.ceil((new Date()*1)*Math.random())+"' type='text/javascript'"+unescape("%3E%3C/script%3E"));</script><!-- X:E ZenBackWidget -->
</body>
</html>

@@ article.html
<!doctype html>
<html>
<head>
    <meta charset="utf-8" />
    <title>#TITLE#</title>
    <link rel="alternate" type="application/rss+xml" title="RSS" href="http://mix3.github.com/index.rdf" />
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

<script type="text/javascript">

  var _gaq = _gaq || [];
  _gaq.push(['_setAccount', 'UA-10744212-4']);
  _gaq.push(['_setDomainName', 'github.com']);
  _gaq.push(['_setAllowHash', 'false']);
  _gaq.push(['_trackPageview']);

  (function() {
    var ga = document.createElement('script'); ga.type = 'text/javascript'; ga.async = true;
    ga.src = ('https:' == document.location.protocol ? 'https://ssl' : 'http://www') + '.google-analytics.com/ga.js';
    var s = document.getElementsByTagName('script')[0]; s.parentNode.insertBefore(ga, s);
  })();

</script>

</head>
<body>
<div id="content" style="display:none">
#CONTENT#
</div>
<!-- X:S ZenBackWidget --><script type="text/javascript">document.write(unescape("%3Cscript")+" src='http://widget.zenback.jp/?base_uri=http%3A//mix3.github.com&nsid=96368406281861426%3A%3A97485858524947259&rand="+Math.ceil((new Date()*1)*Math.random())+"' type='text/javascript'"+unescape("%3E%3C/script%3E"));</script><!-- X:E ZenBackWidget -->
</body>
</html>
