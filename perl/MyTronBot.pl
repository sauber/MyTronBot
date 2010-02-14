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

# 0 = North
# 1 = East
# 2 = South
# 3 = West

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
#   5) TODO: Players too far away from original location: 0
#   6) Number of possible moves until one of the other conditions
#
sub closemoves {
  my($origx,$origy,$x1,$y1,$x2,$y2,$map) = @_;

  my $maxdistance = 3;
  my $score = 1;
  my $playeronecanmove;
  my $playertwocanmove;
  my $playeroneisfaraway;
  my $playertwoisfaraway;
  for my $mymove ( 0 .. 3 ) {
    # Player 1 hits a wall ?
    my @mynew = newpos( $x1, $y1, $mymove );
    my $iswall = $map->{$mynew[0],$mynew[1]} || $_map->IsWall( @mynew );
    next if $iswall;
    ++$playeronecanmove;

    # Player 1 too far away from origin
    my $deltax = abs( $mynew[0] - $origx );
    my $deltay = abs( $mynew[1] - $origy );
    next if $deltax > $maxdistance or $deltay > $maxdistance;
    
    for my $hismove ( 0 .. 3 ) {
      # Player 2 hits a wall ?
      my @hisnew = newpos( $x2, $y2, $hismove );
      my $iswall = $map->{$hisnew[0],$hisnew[1]} || $_map->IsWall( @hisnew );
      next if $iswall;
      ++$playertwocanmove;

      # Player 2 too far away from origin
      my $deltax = abs( $hisnew[0] - $origx );
      my $deltay = abs( $hisnew[1] - $origy );
      next if $deltax > $maxdistance or $deltay > $maxdistance;

      # Distance between players
      $deltax = abs( $mynew[0] - $hisnew[0] );
      $deltay = abs( $mynew[1] - $hisnew[1] );
      if ( $deltax > $maxdistance or $deltay > $maxdistance ) {
        $score -= 1;
      } else {
        # Recursive check all possible next moves
        my $newmap = { %map, "$mynew[0],$mynew[1]"=>1, "$hisnew[0],$hisnew[1]"=>1 };
        $score += closemoves($origx,$origy,@mynew, @hisnew, $newmap);
      }
    }
  }
  return  -1000 if ! $playeronecanmove and   $playertwocanmove;
  return   1000 if   $playeronecanmove and ! $playertwocanmove;
  return   -500 if ! $playeronecanmove and ! $playertwocanmove;
  return $score if   $playeronecanmove and   $playertwocanmove;
}

# Close combat
# When bots are in close proximity, use quantum computing to find best solution
# Need to return the score for any given direction
# 
sub closecombat {
  my $botdistance = 3;
  my(@now) = @{ $_map->{myPos} };
  my(@him) = @{ $_map->{opponentPos} };

  # Create a regional map
  my $minx = $now[0]; $minx = $him[0] if $him[0] < $now[0];
  my $miny = $now[1]; $miny = $him[1] if $him[1] < $now[1];
  my $maxx = $now[0]; $maxx = $him[0] if $him[0] > $now[0];
  my $maxy = $now[1]; $maxy = $him[1] if $him[1] > $now[1];
  $minx -= $botdistance; $minx = 0 if $minx < 0;
  $miny -= $botdistance; $miny = 0 if $miny < 0;
  $maxx += $botdistance; $maxx = $_map->{width}  if $minx > $_map->{width};
  $maxy += $botdistance; $maxy = $_map->{height} if $miny > $_map->{height};

  # 0 = we loose
  # 50 = neutral
  # 100 = we win
  my %regional;
  for my $x ( $minx .. $maxx ) {
    for my $y ( $miny .. $maxy ) {
      $regional{$x,$y} = 50; # 50 neutral value
      $regional{$x,$y} = 0 if $_map->IsWall($x, $y);
    }
  }

  # Test all possibilities, each with a new map
  for my $mymove ( 0 .. 3 ) {
    for my $hismove ( 0 .. 3 ) {
      # Some recursive method calls
      #decisiontree($botdistance, $mymove, $hismove, $regional, $overlay);
    }
  }
  
  
}


# Find longest distance in all four directions
#
sub chooseMove {
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

