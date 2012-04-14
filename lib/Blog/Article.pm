package Blog::Article;

use strict;
use warnings;
use utf8;

use Carp;
use YAML::Tiny;
use File::Basename;
use DateTime::Format::MySQL;
use Text::Markdown 'markdown';
use DateTime::Format::Mail;
use Encode;

use Class::Accessor::Lite (
	rw => [ qw/
		title
		name
		permalink
		date
		category
		tag
		content
		pub_date
		description
	/ ],
);

sub new {
	my ($class, $path, $config) = @_;

	my $args = {};

	$args->{config} = $config ? $config : {};

	$args->{name} = basename($path, '.md');

	my $fh;
	open $fh, $path;

	my $yaml = '';
	my $separate_num = 0;
	while (<$fh>) {
		$separate_num++ if(/^---$/);
		last if (2 <= $separate_num);
		$yaml .= $_;
	}

	if ($separate_num < 2) {
		croak('require article setting');
	}

	my $conf = YAML::Tiny->read_string($yaml)->[0];

	unless (defined $conf->{title}) {
		croak('require title');
	}

	$args->{title} = $conf->{title};

	unless (defined $conf->{date}) {
		croak('require date');
	}

	my $dt = DateTime::Format::MySQL->parse_datetime($conf->{date});
	$dt->set_time_zone('Asia/Tokyo');
	$args->{date} = $dt;
	$args->{pub_date} = DateTime::Format::Mail->format_datetime($dt);

	$args->{permalink} = '/'.$args->{date}->ymd('/').'/'.$args->{name}.'/';

	unless (defined $conf->{category}) {
		$args->{category} = [];
	} else {
		if (ref $conf->{category} eq 'ARRAY') {
			$args->{category} = $conf->{category};
		} else {
			$args->{category} = [$conf->{category}];
		}
	}

	unless (defined $conf->{tag}) {
		$args->{tag} = [];
	} else {
		if (ref $conf->{tag} eq 'ARRAY') {
			$args->{tag} = $conf->{tag};
		} else {
			$args->{tag} = [$conf->{tag}];
		}
	}

	$args->{raw} = do {local $/; <$fh>};
	unless (defined $args->{raw}) {
		croak('require content');
	}

	my $raw = replace($args->{raw}, $args->{config}->{replace}->{before});
	my $content = markdown($raw);
	$args->{content} = replace($content, $args->{config}->{replace}->{after});

	$args->{description} = $args->{content};#html_escape($args->{raw});

	return bless $args, $class;
}

sub replace {
	my ($content, $replace) = @_;
	for my $key (keys %$replace) {
		my $value = $replace->{$key};
		$content =~ s!$key!&{$value}($&)!eg;
	}
	return $content;
};

sub html_escape {
	my $content     = shift;
	my @escape_from = qw(& > < " ');
	my @escape_to = ('&amp;', '&gt;', '&lt;', '&quot;', '&#39;');
	for (my $i = 0; $i <= $#escape_from; $i++) {
	    $content =~ s/$escape_from[$i]/$escape_to[$i]/g;
	}
	return $content;
}

1;
