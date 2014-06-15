package Blog::Conf::Replace;

use Mouse;

has before => (is => "ro", isa => 'HashRef', required => 1);
has after  => (is => "ro", isa => 'HashRef', required => 1);

1;

package Blog::Conf;

use Mouse;
use Mouse::Util::TypeConstraints;

coerce "Blog::Conf::Replace"
	=> from "HashRef"
	=> via { Blog::Conf::Replace->new($_) };

has url        => (is => "ro", isa => "Str", required => 1);
has title      => (is => "ro", isa => "Str", required => 1);
has slogan     => (is => "ro", isa => "Str", required => 1);
has resource   => (is => "ro", isa => "Str", required => 1);
has template   => (is => "ro", isa => "Str", required => 1);
has page_num   => (is => "ro", isa => "Int", required => 1);
has rss_num    => (is => "ro", isa => "Int", required => 1);
has hide_num   => (is => "ro", isa => "Int", required => 1);
has latest_num => (is => "ro", isa => "Int", required => 1);
has replace    => (is => "ro", isa => "Blog::Conf::Replace", coerce => 1, required => 1);

1;
