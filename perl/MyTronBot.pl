########################################################################
###
### Tron Bot for Google AI Challenge
### (c) Soren Dossing, 2010
###
########################################################################

# module containing Tron library functions
use Tron;

#global variable storing the current state of the map
my $_map = new Map();

#Main loop
#   1. Reads in the board and calls chooseMove to pick a random move
#   2. Selects a move at random (number in range 1 -4)
#   3. Calls Tron::MakeMove on the move to pass it to the game engine
while (1) {
  $_map->ReadFromFile();
  my $move = chooseMove();
  Tron::MakeMove($move);
}

########################################################################
###
### Program Description
###
########################################################################

# This program is designed to have several similar strategy methods
# that calculates comparable scores for a set of directions.
#
# All methods share same input/output API:
#   Input: A full list or sub-list of all possible directions to consider.
#   Output: Score for all directions. Higher is better.
#
# A strategy should calculate scores only for directions requested.
#
# Example:
#
#   # Strategy: Go north
#   #
#   sub gonorth {
#     my @dir = @_;
#
#     my @result = (0, 0, 0, 0);
#     for my $move ( @dir ) {
#       $result[$move] = 1 if $move == 0;
#     }
#     return @result;
#   }
#
# These are the possible directions:
#
# 0 = North
# 1 = East
# 2 = South
# 3 = West
#
# Strategies belong to a range. The ranges are:
#    Immediate: Move has to be done now
#   Near range: Up to 3 moves ahead
#    Mid range: Up to 6 moves ahead
#   Long range: 7 or more moves ahead

########################################################################
###
### Generic Map Navigation Methods
###
########################################################################

# Given a position and a move, calculate new position
#
sub newpos {
  my ( $x, $y, $move ) = @_;

  --$y if $move == 0;    # North
  ++$x if $move == 1;    # East
  ++$y if $move == 2;    # South
  --$x if $move == 3;    # West
  my @new = ( $x, $y );
  return @new;
}

# Identify the walls around a position
#
sub walls {
  my ( $x, $y ) = @_;

  my @result;
  for my $move ( 0 .. 3 ) {
    my @new = newpos( $x, $y, $move );
    push @result, $move if $_map->IsWall(@new);
  }
  return @result;
}

# Can opponent reach this position in one move?
#
sub opponentcanreach {
  my ( $x, $y ) = @_;

  my @opponent = @{ $_map->{opponentPos} };
  my $canreach = 0;
  for my $move ( 0 .. 3 ) {
    my @new = newpos( @opponent, $move );

    #warn "Opponent could move to @new and I would be at $x,$y\n";
    if ( $new[0] == $x and $new[1] == $y ) {

      #warn "  Opponent can reach\n";
      $canreach = 1;
      last;
    }
  }

  #warn "  Opponent cannot reach\n" unless $canreach;
  return $canreach;
}

# In a given direction, how many moves until hitting wall?
#
sub distancetowall {
  my ( $x, $y, $move ) = @_;

  my $count = 0;
  my @new = ( $x, $y );
  while ( @new = newpos( @new, $move ) and !$_map->IsWall(@new) ) {
    ++$count;
  }
  return $count;
}

########################################################################
###
### Longrange Strategies
###
########################################################################

# Long range strategies
#   1) Try framing opponent by getting outside
#
sub longrange {
  my @dir = @_;

  # Where is middle of board?
  my $midx = $_map->{width} / 2;
  my $midy = $_map->{height} / 2;

  # Where is opponent
  my ( $hisx, $hisy ) = @{ $_map->{opponentPos} };

  # Where do I want to be? Twice as far from the middle as him.
  my $deltax = $midx - $hisx;
  my $myx    = int( $midx - 2 * $deltax );
  my $deltay = $midy - $hisy;
  my $myy    = int( $midy - 2 * $deltay );

  #warn "Opponent at $hisx,$hisy. I want to be at $myx,$myy\n";

  # Which available direction brings me closer
  my @result = ( 0, 0, 0, 0 );
  my @now = @{ $_map->{myPos} };
  for my $move (@dir) {
    my @new      = newpos( @now, $move );
    my $deltax   = abs( $new[0] - $myx );
    my $deltay   = abs( $new[1] - $myy );
    my $distance = sqrt( $deltax**2 + $deltay**2 );
    $result[$move] = 100 / $distance;
  }

  #warn "longrange: @result\n";
  return @result;
}

########################################################################
###
### Mid Range Strategies
###
########################################################################

# Midrange strategies: Escape
#   1) Stay as far away from directly ahead walls as possible
#   2) Creep around walls if possible
#   3) Don't go into deadends
#
sub midrange {
  my @dir = @_;

  my @result = ( 0, 0, 0, 0 );
  my @now = @{ $_map->{myPos} };
  for my $move (@dir) {

    #my $topscore = 0;
    my $score = distancetowall( @now, $move );

    #warn "Distancescore: $score\n";
    if ( $score >= 2 ) {
      my $creepscore = 1 + creeparound( @now, $move );

      #warn "Creepscore: $creepscore\n";
      $score = $creepscore if $creepscore > $score;

      # Check for deadend...
      my @new = newpos( @now, $move );

      #warn "Starting deadend trace from @now to @new move $move\n";
      my $isdeadend = tracedeadend( @now, newpos( @now, $move ) );

      #warn "Deadendscore: $isdeadend\n";
      $score = 0.5 if $isdeadend;
    }
    # Anything longer than 6 moves is considered out of mid range
    $result[$move] = $score > 5 ? 5 : $score;
  }

  #warn "midrange: @result\n";
  return @result;
}

# How far can we go if we take one step to the side?
#
sub creeparound {
  my ( $x, $y, $move ) = @_;

  my $count = 0;
  if ( $move == 0 or $move == 2 ) {
    my @new = newpos( $x, $y, $move );
    $count += distancetowall( @new, 1 );
    $count += distancetowall( @new, 3 );
  }
  if ( $move == 1 or $move == 3 ) {
    my @new = newpos( $x, $y, $move );
    $count += distancetowall( @new, 0 );
    $count += distancetowall( @new, 2 );
  }
  return $count;
}

# If entering a position only has one next move, keep checking until
# there are at least two moves possible again.
# Otherwise it's a deadend.
#
sub tracedeadend {
  my ( $oldx, $oldy, $newx, $newy ) = @_;

  #my @old = ($x,$y);
  #my @new = newpos($x,$y,$move);
  #while ( numwall >=3 ) {
  #  if 4 then deadend and return
  #}
  #not deadend

  #warn "Deadend wall count moving from $oldx,$oldy to $newx,$newy\n";
  my $numwalls = 0;
  my @gonext;
  for my $dir ( 0 .. 3 ) {
    my @nextpos = newpos( $newx, $newy, $dir );
    next if $nextpos[0] == $oldx and $nextpos[1] == $oldy;
    if ( $_map->IsWall(@nextpos) ) {

      #warn "There is a wall at @nextpos\n";
      ++$numwalls;
    } else {

      #warn "No wall at @nextpos\n";
      @gonext = @nextpos;
    }
  }

  #warn "Deadend trace from $newx $newy to @nextpos\n";
  #warn "Deadend numwalls: $numwalls\n";
  return 1 if $numwalls >= 3;    # No exit. This is a deadend.
  return 0 if $numwalls <= 1;    # Multiple ways. It's not a deadend.
  return tracedeadend( $newx, $newy, @gonext );

  #return 2;
}

########################################################################
###
### Near Range Strategy
###
########################################################################

# Engage in close combat if opponent is nearby.
# Otherwise no strategy.
#
sub nearrange {
  my @dir = @_;

  my @result = ( 0, 0, 0, 0 );
  my $maxdistance = 3;
  for my $move (@dir) {

    #warn "nearrange check move $move of @dir current result @result\n";
    my $deltax = abs( $_map->{myPos}->[0] - $_map->{opponentPos}->[0] );
    my $deltay = abs( $_map->{myPos}->[1] - $_map->{opponentPos}->[1] );
    if ( $deltax <= $maxdistance and $deltay <= $maxdistance ) {

      $result[$move] = closecombat($move);
      # XXX: For now just try stay close to opponent
      #$result[$move] = 2;
    } else {

      # Too far apart for close combat. But a valid move nevertheless.
      $result[$move] = 1;
    }
  }

  warn "nearrange: @result\n";
  return @result;
}

# Close combat.
# When bots are in close proximity, examine all possibilities.
# Calculate overall score for all required direction.
#
sub closecombat {
  my $move = shift;

  # Origin: Position in middle of me an opponent
  my $midx =
    $_map->{opponentPos}->[0] +
    ( $_map->{myPos}->[0] - $_map->{opponentPos}->[0] ) / 2;
  my $midy =
    $_map->{opponentPos}->[1] +
    ( $_map->{myPos}->[1] - $_map->{opponentPos}->[1] ) / 2;

  my @result   = ( 0, 0, 0, 0 );
  my $maxdepth = 3;                # Don't care what happens after 4 moves
  my $score    = 1 + closemoves(
    $midx, $midy,
    @{ $_map->{myPos} },
    @{ $_map->{opponentPos} },
    {}, $maxdepth, $move
  );

  warn "Closecombat for move $move: $score\n";
  return $score;
}

# The rules for close combat.
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
# XXX: TODO:
#   Don't give score for something we don't care about
#   If we can win, stop checking
#   Do testing early. Recursive as late as possible.
#   Only check possible moves once.
#   Do as much as possible before recursing
#
sub closemoves {
  my ( $origx, $origy, $x1, $y1, $x2, $y2, $map, $depth, $firstmove ) = @_;

  my $maxdistance = 3;
  #my $score       = 1;
  #my $playeronecanmove;
  #my $playertwocanmove;
  #my $playeroneisfaraway;
  #my $playertwoisfaraway;
  #my $nummoves = 0;

  warn "closemove $origx, $origy, $x1, $y1, $x2, $y2,, $depth, $firstmove \n";
  # Are we too far away from origin or each other
  my($deltax,$deltay);
  $deltax = abs( $x1 - $origx );
  $deltay = abs( $y1 - $origy );
  return 0 if $deltax > $maxdistance or $deltay > $maxdistance;
  $deltax = abs( $x2 - $origx );
  $deltay = abs( $y2 - $origy );
  return 0 if $deltax > $maxdistance or $deltay > $maxdistance;
  $deltax = abs( $x1 - $x2 );
  $deltay = abs( $y1 - $y2 );
  return 0 if $deltax > $maxdistance or $deltay > $maxdistance;
  warn "Still close enough\n";

  # Check possible moves for me.
  my @mydir;
  if ( $firstmove ) {
    @mydir = ( $firstmove ); # Move is decided for us
  } else {
    for my $move ( 0 .. 3 ) {
      my @new = newpos( $x1, $y1, $move );
      my $iswall = $map->{"$new[0],$new[1]"} || $_map->IsWall(@new);
      push @mydir, $move unless $iswall;
    }
  }

  # Check possible moves for opponent.
  my @hisdir;
  for my $move ( 0 .. 3 ) {
    my @new = newpos( $x2, $y2, $move );
    my $iswall = $map->{"$new[0],$new[1]"} || $_map->IsWall(@new);
    push @hisdir, $move unless $iswall;
  }

  # If one or both of us cannot move...
  return  1000 if   @mydir and ! @hisdir; # I win
  return -1000 if ! @mydir and   @hisdir; # He win
  return  -500 if ! @mydir and ! @hisdir; # Nobody moves. Its's a draw.
  
  # Are we stumbling into each other?
  if ( @mydir == 1 and @hisdir == 1 ) {
    my @mynew = newpos($x1,$y1, $mydir[0]);
    my @hisnew = newpos($x2,$y2, $hisdir[0]);
    if ( $mynew[0] == $hisnew[0] && $mynew[1] == $hisnew[1] ) {
      return -500; # Yes, we will hit each other
    }
  }

  # Can we recurse any deeper?
  --$depth;
  return 0 if $depth <= 0; # It's undecided

  # Check all possible combinations of valid moves
  for my $mymove ( @mydir ) {
    my @mynew = newpos( $x1, $y1, $mymove );

    for my $hismove ( @hisdir ) {
      my @hisnew = newpos( $x2, $y2, $mymove );
  
      # Recursive check all possible next moves
      my $newmap =
        { %$map, "$mynew[0],$mynew[1]" => 1, "$hisnew[0],$hisnew[1]" => 1 };
      my $score =
        closemoves( $origx, $origy, @mynew, @hisnew, $newmap, $depth );
      warn "  $depth $score @mynew, @hisnew\n";
      return $score if $score == -1000 or $score == 1000;
    }
  }
  return 1;
}

########################################################################
###
### Immediate strategy
###
########################################################################

# Immediate Strategy: Don't loose
#   1) Don't hit wall
#   2) Avoid immediate deadends
#   3) Don't move to field that opponent might also go to
#
sub immediate {
  my @dir = @_;

  my @result = ( 0, 0, 0, 0 );
  for my $move (@dir) {

    my @new = newpos( @{ $_map->{myPos} }, $move );

    #warn "Immediate: Checking what's in direction $move\n";
    if ( $_map->IsWall(@new) ) {

      # Don't go into a wall. It's a sure way to loose.
      #warn "Immediate: There is a wall!\n";
      $result[$move] = 0;
    } elsif ( 4 == walls(@new) ) {

      # Avoid going into a dead end. It will make you loose at next move.
      # There is a chance that opponent will die at this move, but it's small.
      #warn "Immediate: It's a deadend!\n";
      $result[$move] = 0.5;
    } elsif ( opponentcanreach(@new) ) {

      # Risking a draw is better than deadends and walls

      #warn "Immediate: Opponent can reach!\n";
      $result[$move] = 0.66;    #
    } else {

      # Nothing immediately in the way for going to this spot.
      #warn "Immediate: Clear!\n";
      $result[$move] = 1;
    }
  }

  #warn "Immediate: @result\n";
  return @result;
}

########################################################################
###
### Move
###
########################################################################

# Compare scores for each direction.
# Only keep the direction with the highest score.
# If more than one direction has same high score, keep all those directions.
# Discard directions not having highest score.
#
sub choosedirections {
  my @dirscore = @_;

  #warn "Initial dirscore: @dirscore\n";
  my $pos = 0;
  my $max;
  my @keep =
    map $_->[0], grep { $_->[1] == $max }    # Keep all equal to highest score
    map { $max ||= $_->[1]; $_ }             # First one is higest score
    sort { $b->[1] <=> $a->[1] }             # Sort by score
    map { [ $pos++, $_ ] } @dirscore;        # Associate direction with score

  #warn "Choosedirections: @keep\n";
  return @keep;
}

# Check immediate, near, mid and long term strategies.
# Follow whichever makes a decision first.
#
sub chooseMove {

  #warn "=== Startpos: @{ $_map->{myPos} }\n";
  my @dir = ( 0, 1, 2, 3 );    # Initial directions. Anything is possible.
  @dir = choosedirections( immediate(@dir) );
  if ( @dir > 1 ) {
#    @dir = choosedirections( nearrange(@dir) );
#    if ( @dir > 1 ) {
      @dir = choosedirections( midrange(@dir) );
      if ( @dir > 1 ) {
        @dir = choosedirections( longrange(@dir) );
      }
#    }
  }
  my $bestmove = shift @dir;

  #warn "Best direction: $bestmove\n";
  return ++$bestmove;
}
