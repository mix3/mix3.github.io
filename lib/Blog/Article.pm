package Blog::Article::Data;

use Mouse;
use Mouse::Util::TypeConstraints;
use DateTime::Format::MySQL;
use DateTime::TimeZone;

my $tz = DateTime::TimeZone->new(name => "Asia/Tokyo");

subtype "DateTimeStr" => as "Str" => where { (/^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}$/) };
subtype "DateTimeFromStr" => as "DateTime";
coerce  "DateTimeFromStr"
	=> from "DateTimeStr"
	=> via { DateTime::Format::MySQL->parse_datetime($_) };

has title    => (is => "ro", isa => "Str", required => 1);
has date     => (is => "ro", isa => "DateTimeFromStr", coerce => 1, required => 1 );
has tag      => (is => "ro", isa => "ArrayRef[Str]", required => 1);
has relation => (is => "ro", isa => "ArrayRef[Str]", default => sub { [] });

1;

package Blog::Article;

use Mouse;
use YAML;
use Carp;
use Text::Markdown qw/markdown/;
use Encode;
use DateTime::Format::Mail;

has file => (is => "ro", isa => "Path::Tiny", required => 1);
has conf => (is => "ro", isa => "Blog::Conf", required => 1);
has name => (is => "ro", isa => "Str", default => sub {
	my ($name, $ext) = split(/\./, $_[0]->file->basename);
	$name;
});

has data => (is => "ro", isa => "Blog::Article::Data", lazy_build => 1);

sub _build_data { Blog::Article::Data->new($_[0]->{_data}) }

has pub_date => (is => "ro", isa => "Str", lazy_build => 1);

sub _build_pub_date { DateTime::Format::Mail->format_datetime($_[0]->data->date) }

has raw => (is => "ro", isa => "Str", lazy_build => 1);

sub _build_raw { $_[0]->{_raw} }

has next     => (is => "rw", isa => "Blog::Article");
has prev     => (is => "rw", isa => "Blog::Article");
has relation => (is => "rw", isa => "ArrayRef[Blog::Article]", default => sub { [] });

has html  => (is => "ro", isa => "Str", lazy_build => 1);

sub _build_html {
	my $replaced_raw = $_[0]->_replace($_[0]->raw, $_[0]->conf->replace->before);
	my $html = markdown($replaced_raw);
	$_[0]->_replace($html, $_[0]->conf->replace->after);
}

sub _replace {
	my ($self, $content, $replace) = @_;
	for my $key (keys %$replace) {
		my $value = $replace->{$key};
		$content =~ s!$key!&{$value}($&)!eg;
	}
	return $content;
};

has perma => (is => "ro", isa => "Str", lazy_build => 1);

sub _build_perma {
	sprintf("/blog/%04d/%02d/%02d/%s/", $_[0]->data->date->year, $_[0]->data->date->month, $_[0]->data->date->day, $_[0]->name);
}

sub BUILD {
	my $self = shift;
	my $fh = $self->file->openr;
	my $yaml = "";
	my $separate_num = 0;
	while (<$fh>) {
		$separate_num++ if (/^---$/);
		last if (2 <= $separate_num);
		$yaml .= $_;
	}
	croak "can't read article yaml" if ($separate_num < 2);
	($self->{_data}) = Load(decode_utf8($yaml));
	 $self->{_raw}   = decode_utf8(do {local $/; <$fh>});
}

1;
