#!/usr/bin/env perl

use strict;
use warnings;
use utf8;

#use Cwd 'realpath';
use FindBin;

use lib $FindBin::Bin.'/../lib';

use Blog;

my $blog = Blog->new();
$blog->generate();
#use Data::Dumper; print Dumper $blog;
#use Article;

#my $blog = Blog->new({
#	root_dir    => realpath($FindBin::Bin.'/../'),
#	config_file => 'config.pl',
#});
#
#use Data::Dumper; print Dumper $blog->output_index;
#use Data::Dumper; print Dumper $blog->output_articles;
#use Data::Dumper; print Dumper $blog->output_page_to_articles;
#use Data::Dumper; print Dumper $blog->output_month_to_articles;
#use Data::Dumper; print Dumper $blog->output_category_to_articles;
#use Data::Dumper; print Dumper $blog->output_tag_to_articles;


#use Data::Dumper;
#for (@{$blog->tags}) {
#	for my $article (@{$blog->tag_to_articles($_)}) {
#		print Dumper $article->{name};
#	}
#}
#print Dumper $blog->categories;

#use Data::Dumper; print Dumper $blog->article_list;
#use Data::Dumper; print Dumper $blog->recent_article_list;

#my $article = Article->new({
#	path => $FindBin::Bin.'/../.resource/1.md',
#});
#
#use Data::Dumper; print Dumper $article;


