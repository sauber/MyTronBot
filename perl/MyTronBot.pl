# perl Random Bot for Tron

# module containing Tron library functions
use Tron;

#global variable storing the current state of the map
my $_map = new Map();

#Main loop 
#   1. Reads in the board and calls chooseMove to pick a random move
#   2. Selects a move at random (number in range 1 -4)
#   3. Calls Tron::MakeMove on the move to pass it to the game engine
while(1){
    $_map->ReadFromFile();
    $move = chooseMove();
    Tron::MakeMove($move);
}

# Basic directions
#
# 0 = North
# 1 = East
# 2 = South
# 3 = West

# Directions next to straight ahead
#
#       WNE
#       012
#       ^^^
#       |||
#  N11<-   ->3N
#  W10<- * ->4E
#  S 9<-   ->5S
#       |||
#       vvv
#       876
#       WSE

# Ranges:
#   Immediate: This Move
#   Near range: 3
#   Mid range: 6
#   Far range: > 6

# Give a position and a move, what is new position
#
sub newpos {
  my($x,$y,$move) = @_;

  --$y if $move == 0; # North
  ++$x if $move == 1; # East
  ++$y if $move == 2; # South
  --$x if $move == 3; # West
  my @new = ( $x, $y );
  return @new;
}

# Calculate distance to wall in a given direction
#
sub distancetowall_old {
  my $move = shift;

  my $count = 1;
  $x = $_map->{myPos}->[0];
  $y = $_map->{myPos}->[1];
  if ( $move == 0 or $move == 8 ) {
    $x--; return 0 if $_map->IsWall( $x, $y );
  }
  if ( $move == 2 or $move == 6 ) {
    $x++; return 0 if $_map->IsWall( $x, $y );
  }
  if ( $move == 3 or $move == 11 ) {
    $y--; return 0 if $_map->IsWall( $x, $y );
  }
  if ( $move == 5 or $move == 9 ) {
    $y++; return 0 if $_map->IsWall( $x, $y );
  }
  #warn "Move $move offset is successful to $x, $y\n"; # XXX: debug
  if ( $move >= 0 and $move <=2 ) {
    while ( ! $_map->IsWall( $x, $y - $count ) ) { ++$count }
  } elsif ( $move >= 3 and $move <= 5 ) {
    while ( ! $_map->IsWall( $x + $count, $y ) ) { ++$count }
  } elsif ( $move >= 6 and $move <= 8 ) {
    while ( ! $_map->IsWall( $x, $y + $count ) ) { ++$count }
  } elsif ( $move >= 9 ) {
    while ( ! $_map->IsWall( $x - $count, $y ) ) { ++$count }
  }
  return --$count;
}

########################################################################
###
### Longrange Strategies
###
########################################################################

# Long range strategies
#   1) Try to get outside of opponent
#
sub longrange {
  my @dir = @_;

  # Where is middle of board?
  my $midx = $_map->{width} / 2;
  my $midy = $_map->{height} / 2;

  # Where is opponent
  my($hisx,$hisy) = @{ $_map->{opponentPos} };

  # Where do I want to be? Twice as far from the middle as him.
  my $deltax = $midx - $hisx;
  my $myx = int ( $midx - 2*$deltax );
  my $deltay = $midy - $hisy;
  my $myy = int ( $midy - 2*$deltay );
  #warn "Opponent at $hisx,$hisy. I want to be at $myx,$myy\n";

  # Which available direction brings me closer
  my @result = (0, 0, 0, 0);
  my @now = @{ $_map->{myPos}} ;
  for my $move ( @dir ) {
    my @new = newpos(@now, $move);
    my $deltax = abs($new[0] - $myx);
    my $deltay = abs($new[1] - $myy);
    my $distance = sqrt( $deltax**2 + $deltay**2 );
    $result[$move] = 100 / $distance;
  }

  #warn "longrange: @result\n";
  return @result;
}

########################################################################
###
### Midrange Strategies
###
########################################################################

# In a given direction, how many moves until hitting wall?
#
sub distancetowall {
  my($x,$y,$move) = @_;

  my $count = 0;
  my @new = ( $x, $y );
  while ( @new = newpos(@new,$move) and ! $_map->IsWall(@new) ) {
    ++$count;
  }
  return $count;
}

# How far can we go if we take one step to the side?
#
sub creeparound {
  my($x,$y,$move) = @_;

  my $count = 0;
  if ( $move == 0 or $move == 2 ) {
    my @new = newpos($x, $y, $move);
    $count += distancetowall(@new,1);
    $count += distancetowall(@new,3);
  }
  if ( $move == 1 or $move == 3 ) {
    my @new = newpos($x, $y, $move);
    $count += distancetowall(@new,0);
    $count += distancetowall(@new,2);
  }
  return $count;
}

# Count number of walls my moving to new position
#
#sub tracenumwall {
#  my($oldx,$oldy,$newx,$newy) = @_;
#
#  #for my $dir ( 0..3 ) {
#  #  @nextpos = newpos( @new, $dir );
#  #  # Is there a wall?
#  #  ++$numwalls if $_map->IsWall( @nextpos );
#  my $numwalls = 0;
#  
#}

# If entering a position only has one next move, keep checking until
# there are at least two moves possible again.
# Otherwise it's a deadend.
#
sub tracedeadend {
  my($oldx,$oldy,$newx,$newy) = @_;

  #my @old = ($x,$y);
  #my @new = newpos($x,$y,$move);
  #while ( numwall >=3 ) {
  #  if 4 then deadend and return
  #}
  #not deadend

  #warn "Deadend wall count moving from $oldx,$oldy to $newx,$newy\n";
  my $numwalls = 0;
  my @gonext;
  for my $dir ( 0..3 ) {
    my @nextpos = newpos( $newx,$newy, $dir );
    next if $nextpos[0] == $oldx and $nextpos[1] == $oldy;
    if ( $_map->IsWall( @nextpos ) ) {
      #warn "There is a wall at @nextpos\n";
      ++$numwalls;
    } else {
      #warn "No wall at @nextpos\n";
      @gonext = @nextpos;
    }
  }
  #warn "Deadend trace from $newx $newy to @nextpos\n";
  #warn "Deadend numwalls: $numwalls\n";
  return 1 if $numwalls >= 3; # No exit. This is a deadend.
  return 0 if $numwalls <= 1; # Multiple ways. It's not a deadend.
  return tracedeadend($newx,$newy,@gonext);
  #return 2;
}

# Midrange strategies: Escape
#   1) Stay as far away from directly ahead walls as possible
#   2) Creep around walls if possible
#   3) Don't go into deadends
#
sub midrange {
  my @dir = @_;

  my @results = (0, 0, 0, 0);
  my @now = @{ $_map->{myPos} };
  for my $move ( @dir ) {
    #my $topscore = 0;
    my $score = distancetowall(@now,$move);
    #warn "Distancescore: $score\n";
    if ( $score >= 2 ) {
      my $creepscore = creeparound(@now,$move);
      #warn "Creepscore: $creepscore\n";
      $score += $creepscore;
      # Check for deadend...
      my @new = newpos(@now,$move);
      #warn "Starting deadend trace from @now to @new move $move\n";
      my $isdeadend = tracedeadend(@now,newpos(@now,$move));
      #warn "Deadendscore: $isdeadend\n";
      $score = 0.5 if $isdeadend;
    }
    $results[$move] = $score > 5 ? 5 : $score;
  }
  #warn "midrange: @results\n";
  return @results;
}

########################################################################
###
### Closed Combat
###
########################################################################

# Given two player positions, the original map, and map modifications
# What are the possible next moves by both players.
# Discard going into walls, and discard going to same position.
# Include map modification for each possible move.
# If no moves available, say why not, such as:
#   1) Player one has no moves: -1000 points
#   2) Player two has no moves: 1000 points
#   3) Both cannot move: -500
#   4) Players too far from each other: -2
#   5) Players too far away from original location: 0
#   6) Players can only collide: -900 (TODO)
#   7) Number of possible moves until one of the other conditions
#
sub closemoves {
  my($origx,$origy,$x1,$y1,$x2,$y2,$map,$depth,$firstmove) = @_;

  return -1 if $depth > 3;
  my $maxdistance = 3;
  my $score = 1;
  my $playeronecanmove;
  my $playertwocanmove;
  my $playeroneisfaraway;
  my $playertwoisfaraway;
  my $nummoves = 0;
  my @dir = (0, 1, 2, 3);
  @dir = ( $firstmove ) if $firstmove;
  for my $mymove ( @dir ) {
    # Player 1 hits a wall ?
    my @mynew = newpos( $x1, $y1, $mymove );
    my $iswall = $map->{$mynew[0],$mynew[1]} || $_map->IsWall( @mynew );
    next if $iswall;
    ++$playeronecanmove;

    for my $hismove ( 0 .. 3 ) {
      # Player 2 hits a wall ?
      my @hisnew = newpos( $x2, $y2, $hismove );
      my $iswall = $map->{$hisnew[0],$hisnew[1]} || $_map->IsWall( @hisnew );
      next if $iswall;
      ++$playertwocanmove;

      ++$nummoves;

      # Player 1 too far away from origin
      my $deltax = abs( $mynew[0] - $origx );
      my $deltay = abs( $mynew[1] - $origy );
      next if $deltax > $maxdistance or $deltay > $maxdistance;

      # Player 2 too far away from origin
      $deltax = abs( $hisnew[0] - $origx );
      $deltay = abs( $hisnew[1] - $origy );
      next if $deltax > $maxdistance or $deltay > $maxdistance;

      # Distance between players
      $deltax = abs( $mynew[0] - $hisnew[0] );
      $deltay = abs( $mynew[1] - $hisnew[1] );
      if ( $deltax == 0 and $deltay == 0 ) {
        # XXX: This is flawed.
        # XXX: Should only apply if there are no other moves available.
        #$score -= 900;
      } elsif ( $deltax > $maxdistance or $deltay > $maxdistance ) {
        $score -= 1;
      } else {
        # Recursive check all possible next moves
        my $newmap = { %map, "$mynew[0],$mynew[1]"=>1, "$hisnew[0],$hisnew[1]"=>1 };
        $score += closemoves($origx,$origy,@mynew, @hisnew, $newmap, 1+$depth);
      }
    }
  }
  $score =  -1000 if ! $playeronecanmove and   $playertwocanmove;
  $score =   1000 if   $playeronecanmove and ! $playertwocanmove;
  $score =   -500 if ! $playeronecanmove and ! $playertwocanmove;
  #return $score if   $playeronecanmove and   $playertwocanmove;
  $score = -900 if $nummoves == 1;
  $debug = " " x $depth;
  $debug .= "score $score, orig($origx,$origy) my($x1,$y1) him($x2,$y2)";
  warn "$debug\n";
  return $score;
}

# Close combat
# When bots are in close proximity, use quantum computing to find best solution
# Need to return the score for any given direction
# 
sub closecombat {
  my @dir = @_;

  my @results = (0, 0, 0, 0);
  my $midx = $_map->{opponentPos}->[0] + ( $_map->{myPos}->[0] - $_map->{opponentPos}->[0] ) / 2;
  my $midy = $_map->{opponentPos}->[0] + ( $_map->{myPos}->[0] - $_map->{opponentPos}->[0] ) / 2;
  for my $move ( @dir ) {
    $results[$move] = closemoves($midx,$midy,@{ $_map->{myPos} }, @{ $_map->{opponentPos} }, {}, 0, $move);
  }
  warn "Closecombat: @results\n";
  return @results;
}


########################################################################
###
### Near Strategies
###
########################################################################

# Given a position and a move, calculate new position
#
sub newpos {
  my($x, $y, $move) = @_,

  my @pos = ( $x, $y );
  @pos = ( $x     , $y - 1 ) if $move == 0; # North
  @pos = ( $x + 1 , $y     ) if $move == 1; # East
  @pos = ( $x     , $y + 1 ) if $move == 2; # South
  @pos = ( $x - 1 , $y     ) if $move == 3; # West
  return @pos;
}

# Is there a wall in this direction from my current position?
#
sub iswall {
  my $move = shift;

  my $haswall = 0;
  my @old = @{ $_map->{myPos} };
  my @new = newpos( @old, $move );
  #warn "Old @old to $move ends at @new\n";
  $haswall = 1 if $_map->IsWall( @new );
  #warn "Wall from @old direction $move: $haswall\n"; # XXX: debug
  return $haswall;
}

# Can opponent reach this position
#
sub opponentcanreach {
  #my($x, $y) = @_;
  my $move = shift;

  my @opponent = @{ $_map->{opponentPos} };
  my($x, $y) = newpos( @{ $_map->{myPos} }, $move );
  my $canreach = 0;
  for my $move ( 0..3 ) {
    my @new = newpos( @opponent, $move );
    #warn "Opponent could move to @new and I would be at $x,$y\n";
    if ( $new[0] == $x and $new[1] == $y ) {
      #warn "Opponent can reach\n";
      $canreach = 1;
      last;
    }
  }
  #warn "Opponent cannot reach\n" unless $canreach;
  return $canreach;
}

# Is move to a dead end?
#
sub deadend {
  my $move = shift;

  my @opponent = @{ $_map->{opponentPos} };
  my @old = @{ $_map->{myPos} };
  my @new = newpos( @old, $move );
  $numwalls = 0;
  for my $dir ( 0..3 ) {
    @nextpos = newpos( @new, $dir );
    # Is there a wall?
    ++$numwalls if $_map->IsWall( @nextpos );
    # Is there also the opponent? Not sure if we should check this.
    ++$numwalls if @nextpos[0] == @opponent[0]
               and @nextpos[1] == @opponent[1];
  }
  #warn "@new has $numwalls walls\n";
  return 1 if $numwalls >= 4;
  return 0;
}

# Near Strategy: Survive
#   1) Don't hit wall
#   2) Don't move to field that opponent might also go to
#   3) XXX TODO: Checkmate
#   4) Avoid immediate deadends
#
sub nearrange {
  my @dir = @_;

  my @results = (1, 1, 1, 1);
  for my $move ( @dir ) {
    #warn "Near: Checking what's in direction $move\n";
    if ( iswall($move) ) {
      #warn "Near: There is a wall!\n";
      $results[$move] = 0;
    } elsif ( deadend($move) ) {
      #warn "Near: It's a deadend!\n";
      $results[$move] = 0.5;
    } elsif ( opponentcanreach($move) ) {
      #warn "Near: Opponent can reach!\n";
      $results[$move] = 0.66;
    } else {
      #warn "Near: Clear!\n";
      $results[$move] = 1;
    }
  }
  #warn "near: @results\n";
  return @results;
}

# Only keep the highest score direction.
# If more than one has same high score, keep all with the same score
#
sub choosedirections {
  my @dirscore = @_;

  #warn "Initial dirscore: @dirscore\n";
  my $pos = 0;
  my $max;
  my @keep =
    map $_->[0], 
    grep { $_->[1] == $max }
    map { $max ||= $_->[1] ; $_ }
    sort { $b->[1] <=> $a->[1] }
    map {[ $pos++, $_ ]}
    @dirscore;

  #my @keep = shift @dir;
  #for my $move ( @dir ) {
  #  if ( $move == $keep[0] ) {
  #    push @keep, $move;
  #  } else {
  #    last;
  #  }
  #}
  #warn "Choosedirections: @keep\n";
  return @keep;
}

# Find longest distance in all four directions
#
sub chooseMove_old {

  # Try out close combat for each move
  #closecombat(0, 1, 2, 3);
  my $move = 0;
  my $longest = 0;
  for my $dir ( 0..11 ) {
    my $distance = distancetowall($dir);
    #warn "Direction $dir distance $distance\n"; # XXX: debug
    if ( $distance >= $longest ) {
      $move = $dir;
      $longest = $distance;
    }
  }
  #return 1+$move;
  my $result = 1;
  #$result = 1 if $move == 1 or $move == 3 or $ move == 11;
  $result = 2 if $move == 2 or $move == 4 or $ move == 6;
  $result = 3 if $move == 5 or $move == 7 or $ move == 9;
  $result = 4 if $move == 0 or $move == 8 or $ move == 10;
  #warn "Best is direction $move, return $result\n";
  return $result;
}

# Check near, mid and long term strategies
# Follow whichever makes a decision first
#
sub chooseMove {
  #warn "=== Startpos: @{ $_map->{myPos} }\n";
  my @dir = (0,1,2,3); # Initial directions. Anything is possible.
  @dir = choosedirections(nearrange(@dir));
  #my $bestmove = shift @dir;
  if ( @dir > 1 ) {
    @dir = choosedirections(midrange(@dir));
    if ( @dir > 1 ) {
      @dir = choosedirections(longrange(@dir));
    }
  }
  my $bestmove = shift @dir;
  #warn "Best direction: $bestmove\n";
  return ++$bestmove;
}
