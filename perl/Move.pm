########################################################################
###
### Compare all moves and choose best one
###
########################################################################

package Move;

# Constructor
#
sub new {
  my $invocant  = shift;
  my $class     = ref($invocant) || $invocant;
  my $self = { @_ };
  bless $self, $class;
  $self->_initialize();
  $self->precheck();
}

# Initializer
#
sub _initialize {
  my $self  = shift;

  # Read parameters from new();
  %{$self} = ( %{$self}, @_ );

  return $self;
}

# Precheck
# Wall and collision check
# Deadend check?
#
sub precheck {
  my $self = shift;

  #return $self;
  # Did any of us hit a wall?
  my($mywall,$hiswall);
  if ( $self->{x1} != $self->{_map}{myPos}[0] and $self->{y1} != $self->{_map}{myPos}[1] ) {
    $mywall = $self->{map}{"$self->{x1},$self->{y1}"}
             || $self->{_map}->IsWall( $self->{x1}, $self->{y1} );
    if ( $mywall ) {
      use Data::Dumper;
      warn "mywall at $self->{x1},$self->{y1}: " . Dumper $self->{map};
    }
  }
  if ( $self->{x2} != $self->{_map}{opponentPos}[0] and $self->{y2} != $self->{_map}{opponentPos}[1] ) {
    $hiswall = $self->{map}{"$self->{x2},$self->{y2}"}
            || $self->{_map}->IsWall( $self->{x2}, $self->{y2} );
  }
  #warn "precheck $self->{depth} iswall: $self->{x1},$self->{y1}:$mywall $self->{x2},$self->{y2}:$hiswall\n";
  return -500 if $mywall and $hiswall;
  return -1000 if $mywall and not $hiswall;
  return 1000 if $hiswall and not $mywall;

  # Did we collide?
  return -500 if $self->{x1} == $self->{x2} and $self->{y1} == $self->{y2};

  # All check passed. We are an object now.
  #warn "  passed\n";
  return $self;
}

# Add children to this node
#
sub addchildren {
  my $self = shift;

  my($mydir,$hisdir) = $self->possiblemoves();
  unless ( @$mydir >= 1 or @$hisdir >= 1 ) {
    #warn "Cannot add nodes to $self->{depth}\n";
    #warn $self->rendermap();
    #die;
  } else {
    #warn sprintf "Will add %s children to depth %s\n", ( scalar(@$mydir)*scalar(@$hisdir) ), $self->{depth};
  }
  for my $mymove ( @$mydir ) {
    for my $hismove ( @$hisdir ) {

      my @mynew = newpos( $self->{x1}, $self->{y1}, $mymove );
      my @hisnew = newpos( $self->{x2}, $self->{y2}, $hismove );
      my $newmap =
      #{ %{$self->{map}}, "$mynew[0],$mynew[1]" => 1, "$hisnew[0],$hisnew[1]" => 1 };
      { %{$self->{map}}, "$self->{x1},$self->{y1}" => 1, "$self->{x2},$self->{y2}" => 1 };

      my $move = new Move(
        origx => $self->{origx},
        origy => $self->{origy},
        x1 => $mynew[0],
        y1 => $mynew[1],
        x2 => $hisnew[0],
        y2 => $hisnew[1],
        'map' => $newmap,
        _map => $self->{_map},
        depth => 1+$self->{depth},
      );

      if ( ref $move ) {
        # We got an object
        #warn "Added node @mynew/@hisnew to $self->{depth}\n";
        $self->{nodes}{$mymove}{$hismove} = {
          node => $move,
          score => 1,
        };
      } else {
        # We got a number, so the move was invalid
        #warn "Added number @mynew/@hisnew to $self->{depth}\n";
        $self->{nodes}{$mymove}{$hismove} = {
          value => $move,
        };
      }
    }
  }
}

# Calculate size of tree
#
sub treesize {
  my $self = shift;

  my $r = "  " x $self->{depth};
  $r .= "$self->{depth}: my($self->{x1},$self->{y1}) his($self->{x2},$self->{y2})";
  #warn "$r\n";
  my $count = 1;
  for my $mymove ( keys %{ $self->{nodes} } ) {
    for my $hismove ( keys %{ $self->{nodes}{$mymove} } ) {
      if ( $self->{nodes}{$mymove}{$hismove}{node} ) {
        $count += $self->{nodes}{$mymove}{$hismove}{node}->treesize();
        # ->treesize() for map {( values %$_ )} values %{ $self->{nodes} };
      }
    }
  }
  return $count;
}

# New location after move
#
sub newpos {
  my($x,$y,$move) = @_;

  --$y if $move == 0;    # North
  ++$x if $move == 1;    # East
  ++$y if $move == 2;    # South
  --$x if $move == 3;    # West
  #die "newpos $x, $y, $move\n" if $x<0 or $y<0 or $x>15 or $y>15;
  my @new = ( $x, $y );
  return @new;
}

# Find out possible moves for me and opponent. Eliminate moves hitting wall.
#
sub possiblemoves {
  my $self = shift;

  # My directions
  my @mydir;
  for my $move ( 0 .. 3 ) {
    #my @new = newpos( @{ $self->{_map}->{myPos} }, $move );
    my @new = newpos( $self->{x1}, $self->{y1}, $move );
    my $iswall = $self->{map}->{"$new[0],$new[1]"}
              || $self->{_map}->IsWall(@new);
    push @mydir, $move unless $iswall;
  }

  # His directions
  my @hisdir;
  for my $move ( 0 .. 3 ) {
    #my @new = newpos( @{ $self->{_map}->{opponentPos} }, $move );
    my @new = newpos( $self->{x2}, $self->{y2}, $move );
    my $iswall = $self->{map}->{"$new[0],$new[1]"} || $self->{_map}->IsWall(@new);
    push @hisdir, $move unless $iswall;
  }

  #warn "possible $self->{depth} at my($self->{x1},$self->{y1}) his($self->{x2},$self->{y2}) mydir @mydir hisdir @hisdir\n";
  
  # Random order, to prevent one particular direction is favored, every time
  #return (
  #  [ sort { rand() <=> rand() } @mydir  ],
  #  [ sort { rand() <=> rand() } @hisdir ]
  #);
  return ( \@mydir, \@hisdir );
}

# Calculate score for a direction. Possibly only for a particular direction.
# 
sub improvescore_old {
  my($self) = @_;

  #warn "Improvescore depth $self->{depth}\n";
  #return $self->{value} if $self->{value};

  # If we already have identified subnodes, then use their values
  # XXX: Choose most narrow paths first
  # Only check nodes that can still be refined.
  if ( $self->{nodes} ) {
    for my $mymove ( keys %{ $self->{nodes} } ) {
      my $score;
      my $dynamic;
      for my $hismove ( keys %{ $self->{nodes}{$mymove} } ) {
        # Create nodes if not already created
        unless ( ref $self->{nodes}{$mymove}{$hismove} ) {
          #my($mymove,$hismove) = split /,/ $node;
          my @mynew = newpos( $self->{x1}, $self->{y1}, $mymove );
          my @hisnew = newpos( $self->{x2}, $self->{y2}, $hismove );
          my $newmap =
          { %{$self->{map}}, "$mynew[0],$mynew[1]" => 1, "$hisnew[0],$hisnew[1]" => 1 };
  
          #warn "Creating $self->{depth} object @mynew $mymove / @hisnew $hismove\n";
          $self->{nodes}{$mymove}{$hismove} = new Move(
            origx => $self->{origx},
            origy => $self->{origy},
            x1 => $mynew[0],
            y1 => $mynew[1],
            x2 => $hisnew[0],
            y2 => $hisnew[1],
            'map' => $newmap,
            _map => $self->{_map},
            depth => 1+$self->{depth},
          );
          #if ( ref $self->{nodes}{$mymove}{$hismove} ) {
          #  warn "  Creation succeeded\n";
          #} else {
          #  warn "  Creation failed\n";
          #}
        }
        if ( $self->{nodes}{$mymove}{$hismove}{value} ) {
          # Use staic value
          $score += $self->{nodes}{$mymove}{$hismove}{value};
        } else {
          # We need to keep recalculating
          ++$dynamic;
          $self->{nodes}{$mymove}{$hismove}->improvescore();
          $score += $self->{nodes}{$mymove}{$hismove}->averagescore();
        }
      }
  
      # Average score of all subnodes
      # XXX: If average score < -500 then we are unlikely to even do a draw
      # so delete this option right away
      # XXX: Other pruning?
      my $nummoves = keys %{ $self->{nodes}{$mymove} };
      #$nummoves ||= 1;
      #warn "For mymove $mymove he has $nummoves moves\n";
      $score = $score / $nummoves;
      $self->{value}{$mymove} = $score unless $dynamic;
      $self->{score}{$mymove} = $score;
    }

    return 1;
  }

  # Otherwise just create subnodes, without checking their value,
  # and instead use count for temporary score.
  my($mydir,$hisdir) = $self->possiblemoves();

  # If one or both of us cannot move
  $self->{value} =  1000 if   @$mydir and ! @$hisdir;   # I win
  $self->{value} = -1000 if ! @$mydir and   @$hisdir;   # He win
  $self->{value} =  -500 if ! @$mydir and ! @$hisdir;   # Both loose
  return $self->{value} if $self->{value};

  # Are we stumbling into each other?
  my($x1,$y1) = @{ $self->{_map}{myPos} };
  my($x2,$y2) = @{ $self->{_map}{opponentPos} };
  if ( @$mydir == 1 and @$hisdir == 1 ) {
    my @mynew = newpos($x1,$y1, $mydir->[0]);
    my @hisnew = newpos($x2,$y2, $hisdir->[0]);
    if ( $mynew[0] == $hisnew[0] && $mynew[1] == $hisnew[1] ) {
      #return -500; # Yes, we will hit each other
      $self->{value} =  -500;
      return $self->{value};
    } else {
    }
  }

  # XXX: Deadend check
  # Deadends can be fine as long as opponent looses before we reach it
  # If there is a choice of deadends, choose the longest
  if ( @$mydir == 1 ) {
  }

  # XXX: Opponent deadend check
  # Likewise, if we can get opponent into a deadend....
  if ( @$hisdir == 1 ) {
  }

  # XXX: Timeout

  # Remember all nodes for next time around
  for my $mymove ( @$mydir ) {
    for my $hismove ( @$hisdir ) {
      $self->{nodes}{$mymove}{$hismove} = 1;
    }
  }

  # Temporary score is count of nodes
  return @$mydir + @$hisdir;
}

sub improvescore {
  my $self = shift;

  if ( keys %{ $self->{nodes} } ) {
    my $dynamic;
    for my $mymove ( keys %{ $self->{nodes} } ) {
      for my $hismove ( keys %{ $self->{nodes}{$mymove} } ) {
        my $move = $self->{nodes}{$mymove}{$hismove};
        #warn "Improving $self->{depth} $move->{node}\n";
        if ( $move->{value} ) {
          #warn "$self->{depth} has value $move->{value}\n";
        } else {
          $move->{node}->improvescore();
          if ( $move->{node}{value} ) {
            delete $move->{node}{score};
            $move->{node}{value} = $move->{node}{value};
          } else {
            ++$dynamic;
            $move->{score} = $move->{node}->averagescore();
          }
        }
      }
    }
    #return $dynamic;
    return 1;
  } else {
    #warn "Adding children to $self->{depth}\n";
    $self->addchildren();
    return 1;
  }
}

# Find out which path was taken
#
sub branch {
  my $self = shift;

  #warn "Check where me and opponent moved to: $self->{_map}{myPos}[0] $self->{_map}{myPos}[1] / $self->{_map}{opponentPos}[0] $self->{_map}{opponentPos}[1]\n";
  for my $mymove ( keys %{ $self->{nodes} } ) {
    for my $hismove ( keys %{ $self->{nodes}{$mymove} } ) {
      #warn "  Compare with $self->{nodes}{$mymove}{$hismove}{x1} $self->{nodes}{$mymove}{$hismove}{y1} / $self->{nodes}{$mymove}{$hismove}{x2} $self->{nodes}{$mymove}{$hismove}{y2}\n";
      
      my $branch;
      my $node = $self->{nodes}{$mymove}{$hismove}{node};
      $branch = $node
          if $self->{_map}{myPos}[0] == $node->{x1}
         and $self->{_map}{myPos}[1] == $node->{y1}
         and $self->{_map}{opponentPos}[0] == $node->{x2}
         and $self->{_map}{opponentPos}[1] == $node->{y2};

      if ( $branch ) {
        warn "Opponent moved from $self->{x2} $self->{y2} to $node->{x2} $node->{y2}\n";
        return $branch;
      }
    }
  }
}

# The direction that currently has the best score
#
sub bestmove {
  my $self = shift;

  #my @dir =
  #  sort { $self->{score}{$b} <=> $self->{score}{$a} }
  #  keys %{ $self->{score} };
  #use Data::Dumper; warn "Bestscore: " . Dumper $self->{score};
  ##warn "bestmove: @dir\n";
  #return $dir[0];

  my %score;
  for my $mymove ( keys %{ $self->{nodes} } ) {
    for my $hismove ( keys %{ $self->{nodes}{$mymove} } ) {
      my $move = $self->{nodes}{$mymove}{$hismove};
      $score{$mymove} += ( $move->{value} || $move->{score} );
    }
    $score{$mymove} /= scalar keys %{ $self->{nodes}{$mymove} };
  }

  use Data::Dumper;
  warn "movescore: " . Dumper \%score;
  my @dir = 
    sort { $score{$b} <=> $score{$a} }
    keys %score;
  warn "bestmove: @dir\n";
  return $dir[0];
}

# Average score of all directions
#
sub averagescore {
  my $self = shift;

  #my $score;
  #my $nummoves = scalar keys %{ $self->{score} };
  #return -1000 unless $nummoves;
  #$score += $self->{score}{$_} for keys %{ $self->{score} };
  #return $score / $nummoves;

  # The score is decided once and for all
  warn "Node $self->{depth} keeps average value $self->{value}\n" if $self->{value};
  return $self->{value} if $self->{value};

  my $score;
  my $count;
  my $dynamic;
  for my $mymove ( keys %{ $self->{nodes} } ) {
    for my $hismove ( keys %{ $self->{nodes}{$mymove} } ) {
      my $move = $self->{nodes}{$mymove}{$hismove};
      if ( $move->{value} ) {
        $score += $move->{value};
        ++$count;
      } elsif ( $move->{score} ) {
        $score += $move->{score};
        ++$count;
        ++$dynamic;
      } else {
        warn "No score for move $mymove, $hismove\n";
      }
    }
  }

  if ( $count ) {
    $score /= $count;
  } else {
    $score = -1000;
  }
  if ( $dynamic ) {
    #warn "Node $self->{depth} has average score $score\n";
    $self->{score} = $score;
  } else {
    #warn "Node $self->{depth} has average value $score\n";
    $self->{value} = $score;
  }
  return $score;
}
  
# Display the map, possibly with override data
#
sub rendermap {
  my $self = shift;
  #my(%override) = @_;

  my($x,$y);
  my @line;
  # Original walls
  for $y ( 0 .. $self->{_map}->{height}-1 ) {
    for $x ( 0 .. $self->{_map}->{width}-1 ) {
      $line[$y] .= $self->{_map}->IsWall($x,$y) ? '#' : ' ' ;
    }
  }
  # Additional walls
  for my $walls ( keys %{ $self->{map} } ) {
    ($x,$y) = split /,/, $walls;
    substr($line[$y],$x,1) ='#';
  }
  # Player positions
  $x = $self->{x2} || $self->{_map}->{opponentPos}[0];
  $y = $self->{y2} || $self->{_map}->{opponentPos}[1];
  substr($line[$y],$x,1) ='2';
  $x = $self->{x1} || $self->{_map}->{myPos}[0];
  $y = $self->{y1} || $self->{_map}->{myPos}[1];
  substr($line[$y],$x,1) ='1';

  my $r = join "\n", @line;
  return $r;
}

1;
