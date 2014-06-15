#!/usr/bin/env perl

use strict;
use warnings;
use FindBin::libs;
use Blog;

Blog->new->run;
#use Data::Dumper; warn Dumper $blog->root;
#use Data::Dumper; warn Dumper $blog->conf;
#print $blog->year_month_to_article->{2013}->{month}->{12}->[-1]->data->title;
#for my $article (values %{$blog->article_hashref}) {
#	print $article->name, "\n";
#	for my $relation (@{$article->relation}) {
#		print "\t", $relation->name, "\n";
#	}
#}
