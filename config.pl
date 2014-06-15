use utf8;
return {
	url        => 'http://mix3.github.io',
	title      => '萌えキャラとは何だったのか',
	slogan     => 'ギークにも絵描きにもなれない者の末路',
	resource   => '.resource',
	template   => '.template',
	page_num   => 5,
	rss_num    => 10,
	latest_num => 5,
	hide_num   => 2,
	replace    => {
		before => {
			'twitter:@([a-zA-Z0-9_]+)' => sub {
				my $name = $1 if (shift =~ /twitter:@(.+)/);
				return "[\@$name](https://twitter.com/#!/$name)";
			},
		},
		after => {
		},
	},
};
