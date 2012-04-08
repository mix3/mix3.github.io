package t::Utils;

use strict;
use warnings;
use utf8;
use lib './lib';
use lib './t/lib';
use FindBin;
use Test::More;

sub import {
    my $caller = caller;
    strict->import;
    warnings->import;
    utf8->import;
}

1;
