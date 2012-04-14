package Blog;

use strict;
use warnings;
use utf8;

use Carp qw/croak/;
use FindBin;
use File::Path qw/mkpath/;
use Blog::Article;
use Text::Xslate;
use Encode;
use XML::RSS;
use HTML::TagCloud;
use URI::Escape;
use Data::Page::Navigation;

use Class::Accessor::Lite (
	rw => [ qw/
		root
		config
	/ ]
);

sub new {
	my $proto = shift;
	my $class = ref $proto || $proto;
	my $self  = ref $_[0] eq 'HASH' ? $_[0] : {@_};
	bless $self, $class;
	$self->{root} = $FindBin::Bin.'/..';
	unless (-f $self->{root}.'/config.pl') {
		croak('config.pl not found');
	}
	$self->{config} = do $self->{root}.'/config.pl';
	$self->{config}->{resource} ||= '.resource';
	$self->{config}->{template} ||= '.template';
	$self->{tx} = Text::Xslate->new(
		path => $self->{root}.'/'.$self->{config}->{template}
	);
	return $self;
}

sub load_article {
	my $self = shift;
	my $search_dir = $self->{root}.'/'.$self->{config}->{resource}.'/*.md';
	for my $path (glob $search_dir) {
		push @{$self->{articles}}, Blog::Article->new($path, $self->{config});
	}
}

sub generate {
	my $self  = shift;
	# load
	$self->load_article();
	$self->load_archive();
	$self->load_tag();
	$self->load_article_list();
	# generate
	$self->_generate_article();
	$self->_generate_index();
	$self->_generate_article_list();
	$self->_generate_rss();
	$self->_generate_archive();
	$self->_generate_tag();
}

sub _generate_index {
	my $self  = shift;
	my $file = $self->root.'/index.html';
	my $render = $self->{tx}->render('list.tx', {
		blog     => $self,
		side     => $self->side,
		articles => $self->latest_articles,
		pager    => $self->{article_list}->{pager}->{1},
	});
	open my $fh, '>', $file;
	print $fh encode_utf8($render); 
	close $fh;
}

sub side {
	my $self = shift;
	return {
		archive_key      => $self->{archive}->{key},
		archive_key2name => $self->{archive}->{key2name},
		tag_cloud        => $self->{tag}->{cloud},
	};
}

sub latest_articles {
	my $self = shift;
	my $num  = shift || $self->{config}->{page_num};
	my @sorted_articles = sort { $b->{date} <=> $a->{date} } @{$self->{articles}};
	my @latest_articles = splice(@sorted_articles, 0, $num);
	return \@latest_articles;
}

sub _generate_article {
	my $self  = shift;
	for my $article (@{$self->{articles}}) {
		my $dir  = $self->root.$article->permalink;
		my $file = $dir.'index.html';
		my $render = $self->{tx}->render('article.tx', {
			blog    => $self,
			side    => $self->side,
			article => $article,
		});
		mkpath($dir);
		open my $fh, '>', $file;
		print $fh encode_utf8($render); 
		close $fh;
	}
}

sub _generate_rss {
	my $self = shift;
	my $rss  = XML::RSS->new(version => '2.0');
	$rss->channel(
		title       => encode_utf8($self->{config}->{title}),
		link        => $self->{config}->{url},
		description => encode_utf8($self->{config}->{description}),
	);
	for my $article (@{$self->latest_articles($self->{config}->{rss_num})}) {
		$rss->add_item(
			title       => encode_utf8($article->title),
			permaLink   => $self->{config}->{url}.$article->permalink,
			pubDate     => $article->pub_date,
			description => "\n<![CDATA[\n".$article->description."]]>\n",
		);
	}
	my $render = $rss->as_string;
    $render =~ s/&#x([0-9A-Fa-f]{2});/pack("H2", $1)/eg;
	my $file = $self->root.'/index.rdf';
	open my $fh, '>', $file;
	print $fh $render;
	close $fh;
}

sub _generate_archive {
	my $self   = shift;
	for my $k (@{$self->{archive}->{key}}) {
		my $dir = $self->root.'/archives/'.$k;
		mkpath($dir);
		my $file = $dir.'/index.html';
		my $render = $self->{tx}->render('list.tx', {
			blog     => $self,
			side     => $self->side,
			articles => $self->{archive}->{key2archive}->{$k},
		});
		open my $fh, '>', $file;
		print $fh encode_utf8($render); 
		close $fh;
	}
}

sub load_archive {
	my $self    = shift;
	my $archive = {};
	for my $article (@{$self->{articles}}) {
		push @{$archive->{$article->{date}->strftime("%Y/%m")}}, $article;
	}
	for my $k (keys %$archive) {
		my @sorted_articles = sort { $b->date <=> $a->date } @{$archive->{$k}};
		$archive->{$k} = \@sorted_articles;
	}
	my @sorted_key = sort { $b cmp $a } keys %$archive;
	my $key2name = {};
	for my $k (@sorted_key) {
		my ($y, $m) = split('/', $k);
		$key2name->{$k} = $y.'年'.$m.'月';
	}
	$self->{archive} = {
		key         => \@sorted_key,
		key2archive => $archive,
		key2name    => $key2name,
	};
}

sub load_tag {
	my $self = shift;
	my $tag  = {};
	for my $article (@{$self->{articles}}) {
		for my $tag_name (@{$article->tag}) {
			push @{$tag->{$tag_name}}, $article;
		}
	}
	my $cloud = HTML::TagCloud->new;
	my $tag_to_num = {};
	for my $k (keys %$tag) {
		$tag_to_num->{$k} = scalar(@{$tag->{$k}});
	}
	for my $k (keys %$tag_to_num) {
		$cloud->add($k, '/tag/'.uri_escape_utf8($k).'/', $tag_to_num->{$k});
	}
	for my $k (keys %$tag) {
		my @sorted_articles = sort { $b->date <=> $a->date } @{$tag->{$k}};
		$tag->{$k} = \@sorted_articles;
	}
	my @sorted_key = sort { $b cmp $a } keys %$tag;
	$self->{tag} = {
		key     => \@sorted_key,
		key2tag => $tag,
		cloud   => $cloud,
	};
}

sub _generate_tag {
	my $self   = shift;
	for my $k (@{$self->{tag}->{key}}) {
		my $dir = $self->root.'/tag/'.$k;
		mkpath($dir);
		my $file = $dir.'/index.html';
		my $render = $self->{tx}->render('list.tx', {
			blog     => $self,
			side     => $self->side,
			articles => $self->{tag}->{key2tag}->{$k},
		});
		open my $fh, '>', $file;
		print $fh encode_utf8($render); 
		close $fh;
	}
}

sub load_article_list {
	my $self = shift;

	my @sorted_articles = sort { $b->date <=> $a->date } @{$self->{articles}};

	my $splice_article = {};
	my $page_num = 0;

	while (0 < @sorted_articles) {
		$page_num++;
		my @page_list = splice(@sorted_articles, 0, $self->config->{page_num});
		$splice_article->{$page_num} = \@page_list;
	}

	my $url       = '/page';
	my $last_page = scalar(keys %$splice_article);
	my $total     = scalar(@{$self->{articles}});
	my $pager     = {};
	for (my $page = 1; $page <= $last_page; $page++) {
		my $navi = Data::Page->new(
			$total,
			$self->config->{page_num},
			$page,
		);
		$navi->pages_per_navigation(5);
		my @list = $navi->pages_in_navigation(5);
		$pager->{$page} = {
			total        => $total,
			url          => $url,
			last_page    => $last_page,
			current_page => $page,
			has_next     => ($page < $last_page) ? 1 : 0,
			has_prev     => (1 < $page)          ? 1 : 0,
			list         => \@list,
		};
	}

	my @sorted_key = sort { $a <=> $b } keys %$splice_article;

	$self->{article_list} = {
		page    => \@sorted_key,
		article => $splice_article,
		pager   => $pager,
	};
}

sub _generate_article_list {
	my $self   = shift;
	for my $page (@{$self->{article_list}->{page}}) {
		my $dir = $self->root.'/page/'.$page;
		mkpath($dir);
		my $file = $dir.'/index.html';
		my $render = $self->{tx}->render('list.tx', {
			blog     => $self,
			side     => $self->side,
			articles => $self->{article_list}->{article}->{$page},
			pager    => $self->{article_list}->{pager}->{$page},
		});
		open my $fh, '>', $file;
		print $fh encode_utf8($render); 
		close $fh;
	}
}

1;
