#!/usr/bin/perl

use strict;
use warnings;

my $_map;
$_map->{raw} = <<EOF;
######
#1   #
#    #
#   2#
######
EOF
chop $_map->{raw};

sub readfile {
  my $y = 0;
  my $x = 0;
  for my $line ( split /\n/, $_map->{raw} ) {
    $x = 0;
    for my $c ( split //, $line ) {
      $_map->{$x}{$y} = 1 if $c ne ' ';
      $_map->{myPos}       = [ $x, $y ] if $c eq '1';
      $_map->{opponentPos} = [ $x, $y ] if $c eq '2';
      ++$x;
    }
    ++$y;
  }
  $_map->{width}  = --$x;
  $_map->{height} = --$y;
}

sub showmap {
  my $r = '';
  for my $y ( 0 .. $_map->{height} ) {
    for my $x ( 0 .. $_map->{width} ) {
      if (  $x == $_map->{opponentPos}[0]
        and $y == $_map->{opponentPos}[1]
        and $x == $_map->{myPos}[0]
        and $y == $_map->{myPos}[1] )
      {
        $r .= '*';
      } elsif ( $x == $_map->{myPos}[0] and $y == $_map->{myPos}[1] ) {
        $r .= '1';
      } elsif ( $x == $_map->{opponentPos}[0]
        and $y == $_map->{opponentPos}[1] )
      {
        $r .= '2';
      } elsif ( $_map->{$x}{$y} ) {
        $r .= '#';
      } else {
        $r .= ' ';
      }
    }
    $r .= "\n";
  }
  return $r;
}



readfile();
print showmap();
