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

