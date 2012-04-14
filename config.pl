use utf8;
return {
	url         => 'http://mix3.github.com',
	title       => '萌えキャラとは何だったのか',
	description => 'ギークにも絵描きにもなれない者の末路',
	resource    => '.resource',
	template    => '.template',
	page_num    => 5,
	rss_num     => 10,
	replace     => {
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
