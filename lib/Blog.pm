package Blog;

use FindBin;
use Mouse;
use Blog::Conf;
use Blog::Article;
use Path::Tiny;
use Text::Xslate;
use Encode;
use JSON::XS;
use XML::RSS;

has 'root' => (is => 'ro', isa => 'Path::Tiny', default => sub {
	my $class = ref $_[0];
	(my $file = "${class}.pm") =~ s!::!/!g;
	if (my $path = $INC{$file}) {
		$path =~ s/$file$//;
		return path("$path/..");
	}
});

has 'conf' => (is => 'ro', isa => 'Blog::Conf', default => sub {
	Blog::Conf->new(do $_[0]->root->child('config.pl'));
});

has 'resource' => (is => 'ro', isa => 'Path::Tiny', default => sub {
	$_[0]->root->child($_[0]->conf->resource);
});

has 'template' => (is => 'ro', isa => 'Path::Tiny', default => sub {
	$_[0]->root->child($_[0]->conf->template);
});

has 'article_hashref' => (is => 'ro', isa => 'HashRef', default => sub {
	my @paths = $_[0]->resource->children(qr/\.md$/);
	my $ret = { map {
		my $article = Blog::Article->new(file => $_, conf => $_[0]->conf);
		($article->name => $article)
	} $_[0]->resource->children(qr/\.md$/) };

	my %relation = ();
	my @desc = sort { $b->data->date <=> $a->data->date || $b->name cmp $a->name } values %$ret;
	for (my $i = 0; $i < @desc; $i++) {
		my $prev    = $desc[$i + 1];
		my $current = $desc[$i];
		my $next    = $i - 1 < 0 ? undef : $desc[$i - 1];
		$current->prev($prev) if ($prev);
		$current->next($next) if ($next);
		for my $r (@{$current->data->relation}) {
			die "relation not found: $r @ ".$current->file->basename unless $ret->{$r};
			$relation{$current->name}->{$r} = 1;
		}
		for my $rr (keys %{$relation{$current->name}}) {
			$relation{$rr}->{$current->name} = 1;
		}
	}
	for my $name (keys %relation) {
		$ret->{$name}->relation([map { $ret->{$_} } keys %{$relation{$name}}]);
	}

	return $ret;
});

has 'tag_to_article' => (is => 'ro', isa => 'HashRef', default => sub {
	my %ret = ();
	my %tmp = ();
	my %map = ();
	for my $article (
		sort {
			$b->data->date <=> $a->data->date || $b->name cmp $a->name
		} values %{$_[0]->article_hashref}
	) {
		for (@{$article->data->tag}) {
			$map{uc $_} ||= $_;
			push @{$tmp{uc $_}}, $article;
		}
	}

	for my $uctag (keys %tmp) {
		$ret{$map{$uctag}} = $tmp{$uctag};
	}

	return \%ret;
});

has 'tag_to_count' => (is => 'ro', isa => 'HashRef', default => sub {
	my %ret = ();
	my %map = ();
	my %cnt = ();
	for my $article (values %{$_[0]->article_hashref}) {
		for (@{$article->data->tag}) {
			$map{$_} = uc $_;
			$cnt{uc $_}++;
		}
	}
	for my $tag (keys %map) {
		$ret{$tag} = $cnt{uc $tag};
	}
	return \%ret;
});

has 'archive'  => (is => 'ro', isa => 'ArrayRef[Blog::Article]', default => sub {
	[sort { $b->data->date <=> $a->data->date || $b->name cmp $a->name } values $_[0]->article_hashref]
});

has 'year_month_to_article'  => (is => 'ro', isa => 'HashRef', default => sub {
	my %ret = ();
	for my $article (@{$_[0]->archive}) {
		my $year = sprintf("%04d", $article->data->date->year);
		my $month = sprintf("%02d", $article->data->date->month);
		push @{$ret{$year}->{article}}, $article;
		push @{$ret{$year}->{month}->{$month}}, $article;
	}
	return \%ret;
});

has 'xslate' => (is => 'ro', isa => 'Text::Xslate', default => sub {
	Text::Xslate->new(
		path => $_[0]->conf->template,
		module => ['Text::Xslate::Bridge::Star'],
	);
});

has 'page_to_article'  => (is => 'ro', isa => 'HashRef', default => sub {
	my %ret = ();
	my @rows = @{$_[0]->archive};
	my $page = 1;
	while (0 < scalar(@rows)) {
		$ret{$page} = [splice(@rows, 0, $_[0]->conf->page_num)];
		$page++;
	}
	return \%ret;
});

has 'rss_article' => (is => 'ro', isa => 'ArrayRef[Blog::Article]', default => sub {
	my @rows = @{$_[0]->archive};
	[splice(@rows, 0, $_[0]->conf->rss_num)];
});

has 'latest_article'  => (is => 'ro', isa => 'ArrayRef[Blog::Article]', default => sub {
	my @rows = @{$_[0]->archive};
	[splice(@rows, 0, $_[0]->conf->latest_num)];
});

sub run {
	my $self = shift;
	$self->_generate_index;
	$self->_generate_page;
	$self->_generate_rss;
	$self->_generate_article;
	$self->_generate_archive;
	$self->_generate_tag;
	$self->_generate_404;
}

sub _output {
	my ($self, $path, $data) = @_;
	my $_path = $self->root->child($path);
	path($_path->dirname)->mkpath;
	my $fh = $_path->openw_utf8;
	print $fh $data;
	close $fh;
}

sub _generate_index {
	my $self = shift;
	$self->_output(
		"index.html",
		$self->xslate->render('index.tx', { blog => $self }),
	);
}

sub _generate_page {
	my $self = shift;
	for my $page (sort { $b <=> $a } keys %{$self->page_to_article}) {
		$self->_output(
			"page/$page/index.html",
			$self->xslate->render('page.tx', { blog => $self, page => $page }),
		);
	}
}

sub _generate_rss {
	my $self = shift;
	my $rss  = XML::RSS->new(version => '2.0');
	$rss->channel(
		title       => $self->conf->title,
		link        => $self->conf->url,
		description => $self->conf->slogan,
	);
	for my $article (@{$self->rss_article}) {
		$rss->add_item(
			title       => $article->data->title,
			permaLink   => $self->conf->url.$article->perma,
			pubDate     => $article->pub_date,
			description => "\n<![CDATA[\n".$article->html."]]>\n",
		);
	}
	my $render = $rss->as_string;
	$render =~ s/&#x([0-9A-Fa-f]{2});/pack("H2", $1)/eg;
	$self->_output('index.rdf', $render);
}

sub _generate_article {
	my $self = shift;
	for my $article (@{$self->archive}) {
		my $year  = sprintf("%04d", $article->data->date->year);
		my $month = sprintf("%02d", $article->data->date->month);
		my $day   = sprintf("%02d", $article->data->date->day);
		my $name  = $article->name;
		$self->_output(
			"blog/$year/$month/$day/$name/index.html",
			$self->xslate->render('article.tx', { blog => $self, article => $article }),
		);
	}
}

sub _generate_archive {
	my $self = shift;
	$self->_output(
		"archives/index.html",
		$self->xslate->render('archive.tx', { blog => $self }),
	);
	for my $year (sort { $b cmp $a } keys %{$self->year_month_to_article}) {
		$self->_output(
			"archives/$year/index.html",
			$self->xslate->render('year_archive.tx', { blog => $self, year => $year }),
		);
		for my $month (sort { $b cmp $a } keys %{$self->year_month_to_article->{$year}->{month}}) {
			$self->_output(
				"archives/$year/$month/index.html",
				$self->xslate->render('month_archive.tx', { blog => $self, year => $year, month => $month }),
			);
		}
	}
}

sub _generate_tag {
	my $self = shift;
	for my $tag (keys %{$self->tag_to_article}) {
		$self->_output(
			"tag/$tag/index.html",
			$self->xslate->render('tag.tx', { blog => $self, tag => $tag }),
		);
	}
}

sub _generate_404 {
	my $self = shift;
	$self->_output(
		"404.html",
		$self->xslate->render('404.tx', { blog => $self }),
	);
}

1;
