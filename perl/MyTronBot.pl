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
sub distancetowall {
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


# Find longest distance in all four directions
#
sub chooseMove {

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

