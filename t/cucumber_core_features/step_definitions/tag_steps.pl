#!perl

use strict;
use warnings;

use Test::More;
use Test::BDD::Cucumber::StepFile;
use Test::BDD::Cucumber::Parser;
use Test::BDD::Cucumber::Model::Scenario;
use Test::BDD::Cucumber::Model::TagSpec;
use Method::Signatures::Simple;

my %ordinals = qw/0 first 1 second 2 third 3 fourth 4 fifth/;

Given qr/a scenario tagged with (.+)/, func ($c) {
	my @tags = $1 =~ m/"\@(.+?)"/g;

	# How many scenarios have we created so far?
	my $count = $c->stash->{'scenario'}->{'count'}++;

	# Create a new one
	my $scenario = Test::BDD::Cucumber::Model::Scenario->new({
		name => $ordinals{ $count },
		tags => \@tags
	});

	# Add it to our list
	my $stack = ($c->stash->{'scenario'}->{'scenarios'} ||= []);
	push( @$stack, $scenario );
};

# OK, seriously? I know it's meant to be natural language, and "Oh look,
# business people are programmers now, lol!" but the syntax the step definition
# file uses is insane. Fail. Grrrr...

sub from_tagspec {
	my ( $c, $expr ) = @_;
	my @scenarios = @{ $c->stash->{'scenario'}->{'scenarios'} };
	my @matched = Test::BDD::Cucumber::Model::TagSpec->new({
		tags => $expr
	})->filter( @scenarios );
	$c->stash->{'scenario'}->{'matched'} = \@matched;
}

When qr/^Cucumber executes scenarios (not |)tagged with (both |)"\@([^"]*)"( (and|or|nor) (without |)"\@([^"]*)")?$/, func ($c) {
	my ( $not_flag, $both, $tag1, $two_part, $joiner, $negate_2, $tag2 ) =
		@{ $c->matches };

	# Normalize nor to or
	$joiner = 'or' if $joiner && $joiner eq 'nor';

	# Negate the second tag if required
	$tag2 = [ not => $tag2 ] if $negate_2;

	# If this is two-part, create that inner atom
	my $inner = $two_part ?
		[ $joiner, $tag1, $tag2 ] :
		$tag1;

	# Create the outer part, based on if it's negated
	my $outer = $not_flag ?
		[ and => [ not => $inner ] ] :
		[ and => $inner ];

	from_tagspec( $c, $outer );
};

# Even I, great regex master, wasn't going to tackle this one in the parser
# above
When qr/^Cucumber executes scenarios tagged with "\@([a-z]+)" but not with both "\@([a-z]+)" and "\@([a-z]+)"/, func ($c) {
	from_tagspec( $c, [ and => $1, [ not => [ and => $2, $3 ] ] ] );
};

Then qr/only the (.+) scenario( is|s are) executed/, func ($c) {
	my $demands = $1;
	my @translates_to;

	# Work out which scenarios we're talking about
	if ( $demands eq 'first two' ) {
		@translates_to = qw/first second/;
	} else {
		$demands =~ s/(,|and)/ /g;
		@translates_to = split(/\s+/, $demands);
	}

	# Work out which were executed
	my @executed = map { $_->name } @{ $c->stash->{'scenario'}->{'matched'} };

	is_deeply( \@executed, \@translates_to, "Right scenarios executed" );
};

# This final scenario has been written in a way that is pretty specific to the
# underlying implementation the author wanted. I didn't implement that way, so
# I'm just going to piggy-back on it, and use the way I've implemented feature
# tags...
Given 'a feature tagged with "@foo"', func ($c) {
	my $feature = Test::BDD::Cucumber::Parser->parse_string(<<'HEREDOC'
@foo
Feature: Name
	Scenario: first
	  Given bla
HEREDOC
	);
	$c->stash->{'scenario'}->{'scenarios'} = $feature->scenarios;
};
Given 'a scenario without any tags', func ($c) {1};
Then 'the scenario is executed', func ($c) {
	ok( $c->stash->{'scenario'}->{'matched'}->[0],
		"Found an executed scenario" );
}


