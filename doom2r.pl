#!/usr/bin/perl
use strict;
use warnings;
use autodie;
use Data::Dumper;
push(@INC, 'pwd');
use DoomMap;
sub shape_vertexes {
	my ($brush_lines) = @_;
	my $vertexes = {};
	foreach my $brush_line(@{ $brush_lines }) {
		$vertexes->{$brush_line->{v1}} = $brush_line->{v1};
		$vertexes->{$brush_line->{v2}} = $brush_line->{v2};
	}
	return [values %{ $vertexes }];
}
sub convert_tex_name {
	my ($tex_name) = @_;
	if (not $tex_name or $tex_name eq "caulk" or $tex_name eq "-") {
		return "common/caulk";
	} elsif ($tex_name eq 'weapclip') {
		return "common/weapclip";
	} elsif ($tex_name =~ /SKY/) {
		return "skies/hip_inter";
	} elsif ($tex_name eq "trigger") {
		return "common/trigger";
	}
	return "freedoom/" . lc $tex_name;
}
sub dot_not_behind_side {
	my ($v1, $v2, $v) = @_;
	if (DoomMap::line_dot_det($v1, $v2, $v) >= 0) {
		return 1;
	}
	return 0;
}
sub lines_crosses {
	my ($v1, $v2, $v3, $v4) = @_;
	my ($c1, $c2, $c3, $c4) = (DoomMap::line_dot_det($v1, $v2, $v3), DoomMap::line_dot_det($v1, $v2, $v4), DoomMap::line_dot_det($v3, $v4, $v1), DoomMap::line_dot_det($v3, $v4, $v2));
	if ($c1 >= 0 and $c2 >= 0) {
		return 0;
	}
	if ($c1 <= 0 and $c2 <= 0) {
		return 0;
	}
	if ($c3 >= 0 and $c4 >= 0) {
		return 0;
	}
	if ($c3 <= 0 and $c4 <= 0) {
		return 0;
	}
	return 1;
}
sub shape_is_ok {
	my ($brush_lines, $vertexes) = @_;
	my ($side, $v1, $v2);
	foreach my $brush_line(@{ $brush_lines }) {
		foreach my $v(@{ $vertexes }) {
			$v1 = $brush_line->{v1};
			$v2 = $brush_line->{v2};
			if ($v == $v1 or $v == $v2) {
				next;
			}
			if (dot_not_behind_side($v1, $v2, $v)) {
				return 0;
			}
		}
	}
	return 1;
}
sub projection_side {
	my ($dir_x, $dir_y) = @_;
	if ($dir_x == $dir_y) {
		if ($dir_x > 0) {
			return 'bottom';
		}
		return 'top';
	}
	if (abs($dir_x) < abs($dir_y)) {
		if ($dir_y < 0) {
			return 'bottom';
		}
		return 'top';
	}
	if (abs($dir_x) > abs($dir_y)) {
		if ($dir_x < 0) {
			return 'left';
		}
		return 'right';
	}
	if ($dir_y < 0) {
		return 'left';
	}
	return 'right';
}
sub tex_offset_scale {
	my ($x, $y, $dir_x, $dir_y, $base_offset) = @_;
	my $offset;
	my $scale;
	my $normal_x = -$dir_y;
	my $normal_y = $dir_x;
	my $projection_side = projection_side($normal_x, $normal_y);
	if ($projection_side eq 'bottom') {
		$offset = -($x + $dir_x) + $base_offset;
		$scale = 1;
	} elsif ($projection_side eq 'right') {
		$offset = -($y + $dir_y) + $base_offset;
		#$offset = $base_offset;
		$scale = 1;
	} elsif ($projection_side eq 'top') {
		$offset = -1 * (-1 * ($x + $dir_x) + $base_offset);
		#$offset = -1 * $base_offset;
		$scale = -1;
	} elsif ($projection_side eq 'left') {
		#$offset = $base_offset;
		$offset = $y + $dir_y + $base_offset;
		$scale = -1;
	}
	return ($offset, $scale);
}
sub brush_text {
	my ($brush_lines, $side_part, $z_top, $z_bottom, $tex1, $tex2, $int_floor_z, $int_ceil_z) = @_;
	my $out = '';
	$out .= "{\n";
	$out .= "( 0.0000 0.0000 $z_top ) ( 0.0000 1.0000 $z_top ) ( 1.0000 0.0000 $z_top ) " . convert_tex_name($tex1) . " 0 0 0 1 1\n";
	$out .= "( 0.0000 0.0000 $z_bottom ) ( 1.0000 0.0000 $z_bottom ) ( 0.0000 1.0000 $z_bottom ) " . convert_tex_name($tex2) . " 0 0 0 1 1\n";
	my ($floor_z, $ceil_z);
	foreach my $brush_line(@{ $brush_lines }) {
		if (%{ $brush_line->{other_sector} }) {
			$floor_z = $brush_line->{other_sector}->{floor_z};
			$ceil_z = $brush_line->{other_sector}->{ceil_z};
		} else {
			$floor_z = 0;
			$ceil_z = 0;
		}
		my $v1 = $brush_line->{v1};
		my $v2 = $brush_line->{v2};
		my $v1_x = $v1->[0];
		my $v1_y = $v1->[1];
		my $v2_x = $v2->[0];
		my $v2_y = $v2->[1];
		my $scale_z = 1;
		my ($o_x, $scale_x) = tex_offset_scale($v1_x, $v1_y, $v2_x - $v1_x, $v2_y - $v1_y, (%{ $brush_line->{side} } ? $brush_line->{side}->{x_offset} : 0));
		my $o_y = (%{ $brush_line->{side} } ? $brush_line->{side}->{y_offset} : 0);
		if ($side_part eq 'lower') {
			if ($brush_line->{lf} and $brush_line->{lf} & 16) {
				$o_y = $ceil_z + $o_y; #maybe $int_floor_z?
			} else {
				$o_y = $floor_z + $o_y;
			}
		} elsif ($side_part eq 'upper') {
			if ($brush_line->{lf} and $brush_line->{lf} & 8) {
				$o_y = $ceil_z + $o_y;
			} else {
				$o_y = $int_ceil_z + $o_y;
			}
		} else {
			if ($brush_line->{lf} and $brush_line->{lf} & 16) {
				$o_y = $floor_z + $o_y;
			} else {
				$o_y = $ceil_z + $o_y;
			}
		}
		my $tex_name = (%{ $brush_line->{side} } ? $brush_line->{side}->{$side_part} : 0);
		$out .= "( $v1_x $v1_y $z_top ) ( $v1_x $v1_y $z_bottom ) ( $v2_x $v2_y $z_top ) " . convert_tex_name($tex_name) . " $o_x $o_y 0 $scale_x $scale_z\n"
	}
	$out .= "}\n";
	return $out;
}
sub sector_brushes_text {
	my ($brush_lines, $sector, $min_z, $max_z) = @_;
	my $out = '';
	$out .= brush_text($brush_lines, "lower", $sector->{floor_z}, $min_z, $sector->{floor_tex}, "-", $sector->{floor_z}, $sector->{ceil_z});
	$out .= brush_text($brush_lines, "upper", $max_z, $sector->{ceil_z}, "-", $sector->{ceil_tex}, $sector->{floor_z}, $sector->{ceil_z});
	return $out;
}
sub brush_split {
	my ($brush_lines, $vertexes, $external_only) = @_;
	my @brush_lines_copy = @{ $brush_lines };
	my ($v1, $v2, $v);
	my ($split_exists, $l1_exists, $l2_exists);
	my $dummy_side_def = { x_offset => 0, y_offset => 0, upper => '-', lower => '-', middle => '-' };
	my $triangles = [];
	my $brush_line;
	my $triangles_num = 0;
	my $triangles_count = 0;
	if ($external_only) {
		$triangles_count = scalar @brush_lines_copy;
	}
	while (1) {
		$triangles_num++;
		if ($triangles_count and $triangles_num > $triangles_count) {
			last;
		}
		$brush_line = shift @brush_lines_copy;
		if (not $brush_line) {
			last;
		}
		if (not ($triangles_num % 50)) {
			$vertexes = shape_vertexes([@brush_lines_copy]);
		}
		$split_exists = 0;
		$v1 = $brush_line->{v1};
		$v2 = $brush_line->{v2};
		VERTEX_CHECK: foreach my $v_check(@{$vertexes}) {
			$v = $v_check;
			if ($v == $v1 or $v == $v2 or dot_not_behind_side($v1, $v2, $v)) {
				next;
			}
			#foreach my $line(@{ $brush_lines }) {
			foreach my $line(@brush_lines_copy) {
				if (lines_crosses($line->{v1}, $line->{v2}, $v, $v1) or lines_crosses($line->{v1}, $line->{v2}, $v2, $v)) {
					next VERTEX_CHECK;
				}
				if (($v == $line->{v1} and $v1 == $line->{v2})
						or ($v1 == $line->{v1} and $v == $line->{v2})
						or ($v1 == $line->{v1} and $v2 == $line->{v2})
						or ($v2 == $line->{v1} and $v1 == $line->{v2})
						or ($v == $line->{v1} and $v2 == $line->{v2})
						or ($v2 == $line->{v1} and $v == $line->{v2})
				) {
					next;
				}
				if (
						DoomMap::line_dot_det($v, $v1, $line->{v1}) <= 0 and
						DoomMap::line_dot_det($v1, $v2, $line->{v1}) <= 0 and
						DoomMap::line_dot_det($v2, $v, $line->{v1}) <= 0 and
						DoomMap::line_dot_det($v, $v1, $line->{v2}) <= 0 and
						DoomMap::line_dot_det($v1, $v2, $line->{v2}) <= 0 and
						DoomMap::line_dot_det($v2, $v, $line->{v2}) <= 0) {
					next VERTEX_CHECK;
				}
			}
			foreach my $v_check2(@{ $vertexes }) {
				if ($v_check2 == $v1 or $v_check2 == $v2 or $v_check2 == $v) {
					next;
				}
				if (DoomMap::line_dot_det($v1, $v2, $v_check2) <= 0 and DoomMap::line_dot_det($v2, $v, $v_check2) <= 0 and DoomMap::line_dot_det($v, $v1, $v_check2) <= 0) {
					next VERTEX_CHECK;
				}
			}
			foreach my $triangle(@{ $triangles }) {
				foreach my $line(@{ $triangle }) {
					if (lines_crosses($line->{v1}, $line->{v2}, $v, $v1) or lines_crosses($line->{v1}, $line->{v2}, $v2, $v)) {
						next VERTEX_CHECK;
					}
					if (($v == $line->{v1} and $v1 == $line->{v2})
							or ($v1 == $line->{v1} and $v == $line->{v2})
							or ($v1 == $line->{v1} and $v2 == $line->{v2})
							or ($v2 == $line->{v1} and $v1 == $line->{v2})
							or ($v == $line->{v1} and $v2 == $line->{v2})
							or ($v2 == $line->{v1} and $v == $line->{v2})
					) {
						next;
					}
					if (
							DoomMap::line_dot_det($v, $v1, $line->{v1}) <= 0 and
							DoomMap::line_dot_det($v1, $v2, $line->{v1}) <= 0 and
							DoomMap::line_dot_det($v2, $v, $line->{v1}) <= 0 and
							DoomMap::line_dot_det($v, $v1, $line->{v2}) <= 0 and
							DoomMap::line_dot_det($v1, $v2, $line->{v2}) <= 0 and
							DoomMap::line_dot_det($v2, $v, $line->{v2}) <= 0) {
						next VERTEX_CHECK;
					}
				}
			}
			$split_exists = 1;
			last;
		}
		if (not $split_exists) {
			print "No split found\n";
			last;
		}
		if (not $v1 or not $v2 or not $v) {
			print "One of vertex missed\n";
			last;
		}
		my $s1 = $dummy_side_def;
		my $s2 = $dummy_side_def;
		my $other_sector1 = {};
		my $other_sector2 = {};
		my $lf1 = 0;
		my $lf2 = 0;
		foreach my $line(@{ $brush_lines }) {
			if ($line->{v1} == $v2 and $line->{v2} == $v) {
				$s2 = $line->{side};
				$other_sector2 = $line->{other_sector};
				$lf2 = $line->{lf};
				$triangles_count-- if $triangles_count;
			} elsif ($line->{v1} == $v and $line->{v2} == $v1) {
				$s1 = $line->{side};
				$other_sector1 = $line->{other_sector};
				$lf1 = $line->{lf};
				$triangles_count-- if $triangles_count;
			}
		}
		push @{ $triangles }, [{ v1 => $v, v2 => $v1, side => $s1, lf => $lf1, other_sector => $other_sector1 },
				{ v1 => $v2, v2 => $v, side => $s2, lf => $lf2, other_sector => $other_sector2 }, $brush_line];
		my @temp = ();
		$l1_exists = 0;
		$l2_exists = 0;
		foreach my $line(@brush_lines_copy) {
			if ($line->{v1} == $v2 and $line->{v2} == $v) {
				$l2_exists = 1;
				next;
			}
			if ($line->{v1} == $v and $line->{v2} == $v1) {
				$l1_exists = 1;
				next;
			}
			#if ($line->{v1} == $v and $line->{v2} == $v2) {
			#	$l2_exists = 1;
			#} elsif ($line->{v1} == $v1 and $line->{v2} == $v) {
			#	$l1_exists = 1;
			#} elsif ($line->{v1} == $v1 and $line->{v2} == $v2) {
			#	next;
			#}
			push @temp, $line;
		}
		@brush_lines_copy = @temp;
		if (not $l1_exists) {
			push @brush_lines_copy, { v1 => $v1, v2 => $v, side => $dummy_side_def, lf => 0, other_sector => {} };
		}
		if (not $l2_exists) {
			push @brush_lines_copy, { v1 => $v, v2 => $v2, side => $dummy_side_def, lf => 0, other_sector => {} };
		}
		print "Added triangle $triangles_num (" . scalar @brush_lines_copy . " sides left)\n";
	}
	return $triangles;
}
sub brush_from_line {
	my ($brush_line, $part, $top, $bottom, $floor_z, $ceil_z, $shift, $solid) = @_;
	my $v1 = $brush_line->{v1};
	my $v2 = $brush_line->{v2};
	my ($dir_x, $dir_y) = ($v2->[0] - $v1->[0], $v2->[1] - $v1->[1]);
	my $l = sqrt($dir_x * $dir_x + $dir_y * $dir_y);
	my $normal_x = $dir_y / $l;
	my $normal_y = -$dir_x / $l;
	my $v1_o = [$v1->[0], $v1->[1]];
	my $v2_o = [$v2->[0], $v2->[1]];
	if ($shift) {
		$v1_o->[0] -= $normal_x;
		$v1_o->[1] -= $normal_y;
		$v2_o->[0] -= $normal_x;
		$v2_o->[1] -= $normal_y;
	}
	my $v3 = [$v2_o->[0] + $normal_x, $v2_o->[1] + $normal_y];
	my $v4 = [$v1_o->[0] + $normal_x, $v1_o->[1] + $normal_y];
	my $extra_tex = 'trigger';
	if ($solid) {
		$extra_tex = 'weapclip';
	}
	my $side = {x_offset => 0, y_offset => 0, upper => $extra_tex, lower => $extra_tex, middle => $extra_tex, sector => {}};
	my $brush_lines = [{ v1 => $v1_o, v2 => $v2_o, side => $brush_line->{side}, lf => $brush_line->{lf}, other_sector => $brush_line->{other_sector} },
			{ v1 => $v2_o, v2 => $v3, side => $side, lf => 0, other_sector => {} },
			{ v1 => $v3, v2 => $v4, side => $side, lf => 0, other_sector => {} },
			{ v1 => $v4, v2 => $v1_o, side => $side, lf => 0, other_sector => {} }
			];
	my $out = "";
	if ($part eq 'lower') {
		$out .= brush_text($brush_lines, "lower", $top, $bottom, $extra_tex, $extra_tex, $floor_z, $ceil_z);
	} elsif ($part eq 'upper') {
		$out .= brush_text($brush_lines, "upper", $top, $bottom, $extra_tex, $extra_tex, $floor_z, $ceil_z);
	} elsif ($part eq 'middle') {
		$out .= brush_text($brush_lines, "middle", $top, $bottom, $extra_tex, $extra_tex, $floor_z, $ceil_z);
	}
	return $out;
}
$|++;
my $map_number = 0;
my $full_world_triangulation = 0;
while (1) {
	if ($ARGV[0] eq '-m') {
		shift @ARGV;
		$map_number = shift @ARGV;
	} elsif ($ARGV[0] eq '-f') {
		shift @ARGV;
		$full_world_triangulation = 1;
	}
	last;
}
my $doom_map_wad_path = $ARGV[0];
my $map_path = $ARGV[1];
my $map_file;
open $map_file, '>', $map_path;
my $doom_map = DoomMap::load($doom_map_wad_path, $map_number);
print $map_file '{
  "classname"  "worldspawn"
  "_minlight" "48"
';
my $entities = "//Entities\n";
my $dummy_side_def = { x_offset => 0, y_offset => 0, upper => '-', lower => '-', middle => '-', sector => 65535 };
my $trigger_side_def = { x_offset => 0, y_offset => 0, upper => 'trigger', lower => 'trigger', middle => 'trigger' };
my $side_def;
foreach my $line(@{ $doom_map->{linedefs} }) {
	if ($line->{type} == 109 or $line->{type} == 38) {
		my $v1 = $line->{v1};
		my $v2 = $line->{v2};
		$entities .= "{\n\"classname\" \"trigger_once\"\n";
		$entities .= "\"spawnflags\" \"4\"";
		$entities .= "\"target\" \"sector" . $line->{sector_tag} . "\"\n";
		my $brush_line = { v1 => $v1,  v2 => $v2, side => {upper => 'trigger', x_offset => 0, y_offset => 0, sector => {}}, lf => 0, other_sector => {} };
		$entities .= brush_from_line($brush_line, 'upper', $doom_map->{max_z}, $doom_map->{min_z}, 0, 0, 4, 0);
		$entities .= "}\n";
	}
}
for (my $i = 0, my $n = @{ $doom_map->{sectors} }; $i <$n; $i++) {
	my $sector = $doom_map->{sectors}->[$i];
	my $brush_lines = [];
	my $special_line_type = 0;
	my $special_line;
	my $special_line_sector_tag;
	my $special_line_remote = 0;
	my $other_side_def;
	my $other_sector = {};
	my $middle_tex;
	#Searching for sector lines
	foreach my $line(@{ $doom_map->{linedefs} }) {
		if (%{ $line->{right_def}} and $line->{right_def}->{sector} == $sector) {
			$side_def = $line->{left_def};
			if (%{ ${side_def} }) {
				$other_sector = $side_def->{sector};
			}
			push @{ $brush_lines }, { v1 => $line->{v1}, v2 => $line->{v2}, side => $side_def, lf => $line->{flags}, other_sector => $other_sector };
		} elsif (%{ $line->{left_def} } and $line->{left_def}->{sector} == $sector) {
			$side_def = $line->{right_def};
			if (%{ ${side_def} }) {
				$other_sector = $side_def->{sector};
			}
			push @{ $brush_lines }, { v2 => $line->{v1}, v1 => $line->{v2}, side => $side_def, lf => $line->{flags}, other_sector => $other_sector };
		} else {
			next;
		}
		if ($line->{type} and $line->{type} != 109 and $line->{type} != 38) {
			$special_line_type = $line->{type};
			$special_line = $line;
			$special_line_sector_tag = $line->{sector_tag};
			print "Special line: $special_line_type " . $line->{sector_tag} . "\n";
		}
		#if (%{ $side_def } and not $side_def->{middle} eq '-' and %{ $other_sector }) {
		#	print $map_file brush_from_line($brush_lines->[(scalar @{ $brush_lines }) - 1], 'middle', $sector->{ceil_z}, $sector->{floor_z}, $sector->{floor_z}, $sector->{ceil_z}, 0, 1);
		#}
	}
	if ($sector->{tag} and not $special_line_type) {
		foreach my $line(@{ $doom_map->{linedefs} }) {
			if ($line->{sector_tag} == $sector->{tag}) {
				$special_line_type = $line->{type};
				$special_line = $line;
				$special_line_sector_tag = $line->{sector_tag};
				$special_line_remote = 1;
				print "Special line: $special_line_type " . $line->{sector_tag} . "\n";
			}
		}
	}
	my $vertexes = shape_vertexes($brush_lines);
	my $splitted_brushes;
	if (shape_is_ok($brush_lines, $vertexes)) {
		print "Sector $i is ok\n";
		$splitted_brushes = [$brush_lines];
	} else {
		print "Split sector $i\n";
		$splitted_brushes = brush_split($brush_lines, $vertexes, 0);
	}
	my $floor_z_save = $sector->{floor_z};
	my $ceil_z_save = $sector->{ceil_z};
	if ($special_line_type) {
		my ($left_def, $right_def);
		my ($ceil_top, $ceil_bottom, $floor_top, $floor_bottom);
		if ($special_line_remote) {
			$floor_bottom = $floor_top = $sector->{floor_z};
			$ceil_bottom = $ceil_top = $sector->{ceil_z};
			foreach my $neighbour(@{ DoomMap::sector_neigbours($doom_map, $sector) }) {
				if ($floor_bottom > $neighbour->{floor_z}) {
					$floor_bottom = $neighbour->{floor_z};
				}
				if ($floor_top < $neighbour->{floor_z}) {
					$floor_top = $neighbour->{floor_z};
				}
				if ($ceil_bottom > $neighbour->{ceil_z}) {
					$ceil_bottom = $neighbour->{ceil_z};
				}
				if ($ceil_top < $neighbour->{ceil_z}) {
					$ceil_top = $neighbour->{ceil_z};
				}
			}
		} else {
			my ($z1, $z2, $z3, $z4) = (0, 0, 0, 0);
			$right_def = $special_line->{right_def};
			$left_def = $special_line->{left_def};
			if (%{ $right_def } and %{ $right_def->{sector} }) {
				$z1 = $right_def->{sector}->{ceil_z};
				$z3 = $right_def->{sector}->{floor_z};
			}
			if (%{ $left_def } and %{ $left_def->{sector} }) {
				$z2 = $left_def->{sector}->{ceil_z};
				$z4 = $left_def->{sector}->{floor_z};
			}
			if ($z1 > $z2) {
				$ceil_top = $z1;
				$ceil_bottom = $z2;
			} else {
				$ceil_top = $z2;
				$ceil_bottom = $z1;
			}
			if ($z3 > $z4) {
				$floor_top = $z3;
				$floor_bottom = $z4;
			} else {
				$floor_top = $z4;
				$floor_bottom = $z3;
			}
		}
		if ($special_line_type == 1 or $special_line_type == 117
				or $special_line_type == 26 or $special_line_type == 32 or $special_line_type == 99
				or $special_line_type == 133 or $special_line_type == 27 or $special_line_type == 33
				or $special_line_type == 136 or $special_line_type == 137 or $special_line_type == 28
				or $special_line_type == 34 or $special_line_type == 134 or $special_line_type == 135
				or $special_line_type == 31
				or ($special_line_type == 109 and $special_line_sector_tag == $sector->{tag})
				or ($special_line_type == 103 and $special_line_sector_tag == $sector->{tag})
				) {
			#DOOR
			if ($sector->{ceil_z} < $ceil_top) {
				print "Create door...\n";
				my $targeted = 0;
				if ($sector->{tag}) {
					foreach my $line(@{ $doom_map->{linedefs} }) {
						if ((not %{ $line->{right_def} } or $line->{right_def}->{sector} != $sector) and (not %{ $line->{left_def} } or $line->{left_def}->{sector} != $sector) and $line->{sector_tag} == $sector->{tag}) {
							#Remote trigger
							$targeted = 1;
						}
					}
				}
				$entities .= "{\n\"classname\" \"func_door\"\n\"angle\" \"-1\"\n";
				$entities .= "\"comment\" \"line_type_$special_line_type\"\n";
				$entities .= "\"sounds\" \"1\"\n";
				if ($special_line_type == 26 or $special_line_type == 32 or $special_line_type == 99 or $special_line_type == 133) {
					$entities .= "\"spawnflags\" \"16\"\n\"wait\" \"-1\"\n";
				} elsif ($special_line_type == 27 or $special_line_type == 33 or $special_line_type == 136 or $special_line_type == 137) {
					$entities .= "\"spawnflags\" \"8\"\n\"wait\" \"-1\"\n";
				} elsif ($special_line_type == 28 or $special_line_type == 34 or $special_line_type == 134 or $special_line_type == 135) {
					$entities .= "\"spawnflags\" \"64\"\n\"wait\" \"-1\"\n";
				} elsif ($special_line_type == 31 or $special_line_type == 109 or $targeted) {
					$entities .= "\"wait\" \"-1\"\n";
				}
				if ($targeted) {
					$entities .= "\"targetname\" \"sector" . $sector->{tag} . "\"\n";
				}
				foreach my $splitted_brush(@{ $splitted_brushes }) {
					$entities .= brush_text($splitted_brush, "upper", $ceil_top, $ceil_bottom, "caulk", $sector->{ceil_tex}, $sector->{floor_z}, $sector->{ceil_z});
				}
				$entities .= "}\n";
				$sector->{ceil_z} = $ceil_top;
			}
		} elsif ($special_line_type == 88 or $special_line_type == 62 or $special_line_type == 123 or $special_line_type == 120 or (($special_line_type == 71 or $special_line_type == 38) and $special_line_remote)) {
			if ($sector->{tag} == $special_line->{sector_tag}) {
				print "Create lift...\n";
				foreach my $neighbour(@{ DoomMap::sector_neigbours($doom_map, $sector) }) {
					if ($floor_bottom > $neighbour->{floor_z}) {
						$floor_bottom = $neighbour->{floor_z}
					}
				}
				if ($sector->{floor_z} > $floor_bottom) {
					print "Lift created\n";
					my $targeted = 0;
					if ($sector->{tag}) {
						foreach my $line(@{ $doom_map->{linedefs} }) {
							if ((not %{ $line->{right_def} } or $line->{right_def}->{sector} != $sector) and (not %{ $line->{left_def} } or $line->{left_def}->{sector} != $sector) and $line->{sector_tag} == $sector->{tag}) {
								#Remote trigger
								$targeted = 1;
							}
						}
					}
					$entities .= "{\n\"classname\" \"func_door\"\n";
					if ($targeted) {
						$entities .= "\"wait\" \"-1\"\n";
						$entities .= "\"angle\" \"-2\"\n";
						$entities .= "\"sounds\" \"1\"\n";
						$entities .= "\"targetname\" \"sector" . $sector->{tag} . "\"\n";
					} else {
						$entities .= "\"spawnflags\" \"1\"\n";
						$entities .= "\"wait\" \"3\"\n";
						$entities .= "\"angle\" \"-2\"\n";
						$entities .= "\"sounds\" \"1\"\n";
					}
					$entities .= "\"comment\" \"line_type_$special_line_type\"\n";
					if ($special_line_sector_tag) {
						$entities .= "\"target\" \"sector$special_line_sector_tag\"\n";
					}
					foreach my $splitted_brush(@{ $splitted_brushes }) {
						$entities .= "// sector $i\n";
						my $vert_shift = $sector->{floor_z} - $floor_bottom;
						for my $brush(@$splitted_brush) {
							if ($brush->{side}->{y_offset}) {
								$brush->{side}->{y_offset} -= $vert_shift;
							}
						}
						$entities .= brush_text($splitted_brush, "lower", $sector->{floor_z}, $floor_bottom, $sector->{floor_tex}, "caulk", $sector->{floor_z}, $sector->{ceil_z});
						for my $brush(@$splitted_brush) {
							if ($brush->{side}->{y_offset}) {
								$brush->{side}->{y_offset} += $vert_shift;
							}
						}
					}
					$entities .= "}\n";
					$sector->{floor_z} = $floor_bottom;
				} else {
					print "Lift skipped, no enough space $floor_bottom <= " . $sector->{floor_z} . "\n";
				}
			}
		} elsif (not $special_line_remote and ($special_line_type == 23 or $special_line_type == 11 or $special_line_type == 103 or $special_line_type == 71)) {
			#Buttons
			my $v1 = $special_line->{v1};
			my $v2 = $special_line->{v2};
			$entities .= "{\n\"classname\" \"func_door\"\n";
			$entities .= "\"lip\" \"-2\"\n";
			$entities .= "\"wait\" \"-1\"\n";
			$entities .= "\"noise1\" \"misc/menu1.wav\"\n";
			$entities .= "\"sounds\" \"1\"\n";
			if ($special_line_type == 11) {
				$entities .= "\"target\" \"endlevel\"\n";
			} else {
				$entities .= "\"target\" \"sector" . $special_line->{sector_tag} . "\"\n";
			}
			$entities .= "\"movedir\" \"" . (-($v2->[1] - $v1->[1])) . " " . ($v2->[0] - $v1->[0]) . " 0\"\n";
			my $brush_line;
			my $other_sector = {};
			if (%{ $special_line->{left_def} } and $special_line->{left_def}->{sector} == $sector) {
				#if (%{ $special_line->{left_def} }) {
				#	$other_sector = $special_line->{right_def}->{sector};
				#}
				$brush_line = { v1 => $v1,  v2 => $v2, side => $special_line->{left_def},
						lf => $special_line->{flags}, other_sector => $sector };
			} elsif (%{ $special_line->{right_def} } and $special_line->{right_def}->{sector} == $sector) {
				#if (%{ $special_line->{right_def} }) {
				#	$other_sector = $special_line->{left_def}->{sector};
				#}
				$brush_line = { v1 => $v2,  v2 => $v1, side => $special_line->{right_def},
						lf => $special_line->{flags}, other_sector => $sector };
			}
			if (not ($brush_line->{side}->{upper} eq '-')) {
				$brush_line->{side}->{upper} =~ s/^SW2/SW1/;
				$entities .= brush_from_line($brush_line, 'upper', $doom_map->{max_z}, $sector->{ceil_z}, $sector->{floor_z}, $sector->{ceil_z}, 1, 1);
				$brush_line->{side}->{upper} =~ s/^SW1/SW2/;
			}
			if (not ($brush_line->{side}->{middle} eq '-')) {
				$brush_line->{side}->{middle} =~ s/^SW2/SW1/;
				$entities .= brush_from_line($brush_line, 'middle', $sector->{ceil_z}, $sector->{floor_z}, $sector->{floor_z}, $sector->{ceil_z}, 1, 1);
				$brush_line->{side}->{middle} =~ s/^SW1/SW2/;
			}
			if (not ($brush_line->{side}->{lower} eq '-')) {
				$brush_line->{side}->{lower} =~ s/^SW2/SW1/;
				$entities .= brush_from_line($brush_line, 'lower', $sector->{floor_z}, $doom_map->{min_z}, $sector->{floor_z}, $sector->{ceil_z}, 1, 1);
				$brush_line->{side}->{lower} =~ s/^SW1/SW2/;
			}
			$entities .= "}\n";
		} else {
			$entities .= "{\n";
			$entities .= "\"classname\" \"linetype$special_line_type\"\n";
			$entities .= "\"origin\" \"" . ($special_line->{v1}->[0] + $special_line->{v2}->[0]) / 2 . " " . ($special_line->{v1}->[1] + $special_line->{v2}->[1]) / 2 . " " . ($sector->{floor_z} + 10) . "\"\n";
			$entities .= "\"target\" \"sector" . $special_line->{sector_tag} . "\"\n";
			$entities .= "}\n";
			print "Unhandled line type $special_line_type\n";
		}
	#} elsif ($sector->{tag} > 0) {
	#	print "Tagged brush\n";
	#	my $neighbours = DoomMap::sector_neigbours($doom_map, $sector);
	#	my $floor_bottom = $doom_map->{max_z};
	#	foreach my $neighbour(@{ $neighbours }) {
	#		if ($floor_bottom > $neighbour->{floor_z}) {
	#			$floor_bottom = $neighbour->{floor_z}
	#		}
	#	}
	#	$entities .= "{\n\"classname\" \"func_door\"\n\"angle\" \"-2\"\n\"sounds\" \"1\"\n";
	#	$entities .= "\"targetname\" \"sector" . $sector->{tag} . "\"\n";
	#	$entities .= "\"wait\" \"-1\"\n";
	#	foreach my $splitted_brush(@{ $splitted_brushes }) {
	#		$entities .= brush_text($splitted_brush, "lower", $sector->{floor_z}, $floor_bottom - 4, $sector->{floor_tex}, 'caulk', $sector->{floor_z}, $sector->{ceil_z});
	#	}
	#	$entities .= "}\n";
	#	$sector->{floor_z} = $floor_bottom;
	}
	print "Print brushes\n";
	foreach my $splitted_brush(@{ $splitted_brushes }) {
		print $map_file "// sector $i\n";
		print $map_file sector_brushes_text($splitted_brush, $sector, $doom_map->{min_z}, $doom_map->{max_z});
	}
	$sector->{floor_z} = $floor_z_save;
	$sector->{ceil_z} = $ceil_z_save;
}
my $world_lines = [];
my $other_sector;
my $world_sector = {'floor_z' => 0, 'ceil_z' => 0, 'floor_tex' => '-', 'ceil_tex' => '-'};
foreach my $line(@{ $doom_map->{linedefs} }) {
	$other_sector = $world_sector;
	if (not %{ $line->{right_def} }) {
		$side_def = $line->{left_def};
		$other_sector = $side_def->{sector};
		push @{ $world_lines }, { v1 => $line->{v1}, v2 => $line->{v2}, side => $side_def, lf => $line->{flags}, other_sector => $other_sector };
	} elsif (not %{ $line->{left_def} }) {
		$side_def = $line->{right_def};
		$other_sector = $side_def->{sector};
		push @{ $world_lines }, { v2 => $line->{v1}, v1 => $line->{v2}, side => $side_def, lf => $line->{flags}, other_sector => $other_sector };
	}
}
my ($v1, $v2, $v3, $v4) = ([$doom_map->{min_x}, $doom_map->{min_y}], [$doom_map->{min_x}, $doom_map->{max_y}], [$doom_map->{max_x}, $doom_map->{max_y}], [$doom_map->{max_x}, $doom_map->{min_y}]);
push @{ $world_lines }, { v1 => $v1, v2 => $v2, side => $dummy_side_def, lf => 0, other_sector => {} };
push @{ $world_lines }, { v1 => $v2, v2 => $v3, side => $dummy_side_def, lf => 0, other_sector => {} };
push @{ $world_lines }, { v1 => $v3, v2 => $v4, side => $dummy_side_def, lf => 0, other_sector => {} };
push @{ $world_lines }, { v1 => $v4, v2 => $v1, side => $dummy_side_def, lf => 0, other_sector => {} };
print "Split world sector\n";
my $splitted_brushes = brush_split($world_lines, shape_vertexes($world_lines), not $full_world_triangulation);
print "Print world triangle\n";
foreach my $splitted_brush(@{ $splitted_brushes }) {
	print $map_file "// world triangle\n";
	print $map_file brush_text($splitted_brush, 'middle', $doom_map->{max_z}, $doom_map->{min_z}, "caulk", "caulk", 0, 0);
}
my $box_brush_lines = [
		{ v1 => $v1, v2 => $v2, side => $dummy_side_def, lf => 0, other_sector => {} },
		{ v1 => $v2, v2 => $v3, side => $dummy_side_def, lf => 0, other_sector => {} },
		{ v1 => $v3, v2 => $v4, side => $dummy_side_def, lf => 0, other_sector => {} },
		{ v1 => $v4, v2 => $v1, side => $dummy_side_def, lf => 0, other_sector => {} },
		];
print $map_file brush_text($box_brush_lines, 'middle', $doom_map->{max_z} + 16, $doom_map->{max_z}, "caulk", "caulk", 0, 0);
print $map_file brush_text($box_brush_lines, 'middle', $doom_map->{min_z}, $doom_map->{min_z} - 16, "caulk", "caulk", 0, 0);
$v1 = [$doom_map->{min_x} - 16, $doom_map->{min_y}];
$v2 = [$doom_map->{min_x} - 16, $doom_map->{max_y}];
$v3 = [$doom_map->{min_x}, $doom_map->{max_y}];
$v4 = [$doom_map->{min_x}, $doom_map->{min_y}];
$box_brush_lines = [
		{ v1 => $v1, v2 => $v2, side => $dummy_side_def, lf => 0, other_sector => {} },
		{ v1 => $v2, v2 => $v3, side => $dummy_side_def, lf => 0, other_sector => {} },
		{ v1 => $v3, v2 => $v4, side => $dummy_side_def, lf => 0, other_sector => {} },
		{ v1 => $v4, v2 => $v1, side => $dummy_side_def, lf => 0, other_sector => {} },
		];
print $map_file brush_text($box_brush_lines, 'middle', $doom_map->{max_z}, $doom_map->{min_z}, "caulk", "caulk", 0, 0);
$v1 = [$doom_map->{max_x}, $doom_map->{min_y}];
$v2 = [$doom_map->{max_x}, $doom_map->{max_y}];
$v3 = [$doom_map->{max_x} + 16, $doom_map->{max_y}];
$v4 = [$doom_map->{max_x} + 16, $doom_map->{min_y}];
$box_brush_lines = [
		{ v1 => $v1, v2 => $v2, side => $dummy_side_def, lf => 0, other_sector => {} },
		{ v1 => $v2, v2 => $v3, side => $dummy_side_def, lf => 0, other_sector => {} },
		{ v1 => $v3, v2 => $v4, side => $dummy_side_def, lf => 0, other_sector => {} },
		{ v1 => $v4, v2 => $v1, side => $dummy_side_def, lf => 0, other_sector => {} },
		];
print $map_file brush_text($box_brush_lines, 'middle', $doom_map->{max_z}, $doom_map->{min_z}, "caulk", "caulk", 0, 0);
$v1 = [$doom_map->{min_x}, $doom_map->{min_y} - 16];
$v2 = [$doom_map->{min_x}, $doom_map->{min_y}];
$v3 = [$doom_map->{max_x}, $doom_map->{min_y}];
$v4 = [$doom_map->{max_x}, $doom_map->{min_y} - 16];
$box_brush_lines = [
		{ v1 => $v1, v2 => $v2, side => $dummy_side_def, lf => 0, other_sector => {} },
		{ v1 => $v2, v2 => $v3, side => $dummy_side_def, lf => 0, other_sector => {} },
		{ v1 => $v3, v2 => $v4, side => $dummy_side_def, lf => 0, other_sector => {} },
		{ v1 => $v4, v2 => $v1, side => $dummy_side_def, lf => 0, other_sector => {} },
		];
print $map_file brush_text($box_brush_lines, 'middle', $doom_map->{max_z}, $doom_map->{min_z}, "caulk", "caulk", 0, 0);
$v1 = [$doom_map->{min_x}, $doom_map->{max_y}];
$v2 = [$doom_map->{min_x}, $doom_map->{max_y} + 16];
$v3 = [$doom_map->{max_x}, $doom_map->{max_y} + 16];
$v4 = [$doom_map->{max_x}, $doom_map->{max_y}];
$box_brush_lines = [
		{ v1 => $v1, v2 => $v2, side => $dummy_side_def, lf => 0, other_sector => {} },
		{ v1 => $v2, v2 => $v3, side => $dummy_side_def, lf => 0, other_sector => {} },
		{ v1 => $v3, v2 => $v4, side => $dummy_side_def, lf => 0, other_sector => {} },
		{ v1 => $v4, v2 => $v1, side => $dummy_side_def, lf => 0, other_sector => {} },
		];
print $map_file brush_text($box_brush_lines, 'middle', $doom_map->{max_z}, $doom_map->{min_z}, "caulk", "caulk", 0, 0);

print $map_file "}\n";
foreach my $thing(@{ $doom_map->{things} }) {
	if ($thing->{flags} & 16 or not $thing->{flags} & 4) {
		next;
	}
	my $s = DoomMap::sector_search($doom_map, $thing->{x}, $thing->{y});
	my $z = $s->{floor_z} + 20;
	$entities .= "{\n";
	if ($thing->{type} == 1) {
		$entities .= "\"classname\" \"info_player_start\"\n";
	} elsif ($thing->{type} > 1 and $thing->{type} < 5) {
		$entities .= "\"classname\" \"info_player_coop\"\n";
	} elsif ($thing->{type} == 2014) {
		$entities .= "\"classname\" \"item_health_small\"\n";
	} elsif ($thing->{type} == 2011) {
		$entities .= "\"classname\" \"item_health_small\"\n";
	} elsif ($thing->{type} == 2015) {
		$entities .= "\"classname\" \"item_armor_small\"\n";
	} elsif ($thing->{type} == 2035) {
		$entities .= "\"classname\" \"misc_barrel_explosive\"\n";
	} elsif ($thing->{type} == 2018) {
		$entities .= "\"classname\" \"item_armor_big\"\n";
	} elsif ($thing->{type} == 5 || $thing->{type} == 40) {
		$entities .= "\"classname\" \"item_key_silver\"\n";
	} elsif ($thing->{type} == 6 || $thing->{type} == 39) {
		$entities .= "\"classname\" \"item_key_gold\"\n";
	} elsif ($thing->{type} == 13 || $thing->{type} == 38) {
		$entities .= "\"classname\" \"item_key_blood\"\n";
	} elsif ($thing->{type} == 16) {
		$entities .= "\"classname\" \"monster_boss1_spawn\"\n";
	} elsif ($thing->{type} == 9) {
		$entities .= "\"classname\" \"monster_heavysoldier_spawn\"\n";
	} elsif ($thing->{type} == 43) {
		$entities .= "\"classname\" \"misc_tree\"\n";
	} elsif ($thing->{type} == 3001) {
		$entities .= "\"classname\" \"monster_rlgirl_spawn\"\n";
	} elsif ($thing->{type} == 3002) {
		$entities .= "\"classname\" \"monster_spearguy_spawn\"\n";
	} elsif ($thing->{type} == 3004) {
		$entities .= "\"classname\" \"monster_soldier_spawn\"\n";
	} elsif ($thing->{type} == 2001 || $thing->{type} == 82) {
		$entities .= "\"classname\" \"weapon_uzi\"\n";
	} elsif ($thing->{type} == 2002) {
		$entities .= "\"classname\" \"weapon_supershotgun\"\n";
	} elsif ($thing->{type} == 2004) {
		$entities .= "\"classname\" \"weapon_hlac\"\n";
	} elsif ($thing->{type} == 2005) {
		$entities .= "\"classname\" \"weapon_grenadelauncher\"\n";
	} elsif ($thing->{type} == 2006) {
		$entities .= "\"classname\" \"weapon_crylink\"\n";
	} elsif ($thing->{type} == 2003) {
		$entities .= "\"classname\" \"weapon_rocketlauncher\"\n";
	} elsif ($thing->{type} == 2023) {
		$entities .= "\"classname\" \"item_health_mega\"\n";
	} elsif ($thing->{type} == 2025) {
		$entities .= "\"classname\" \"item_invincible\"\n";
	} elsif ($thing->{type} == 2083) {
		$entities .= "\"classname\" \"item_health_mega\"\n";
	} elsif ($thing->{type} == 2015) {
		$entities .= "\"classname\" \"item_armor_large\"\n";
	} elsif ($thing->{type} == 2013) {
		$entities .= "\"classname\" \"item_health_mega\"\n";
	} elsif ($thing->{type} == 2024) {
		$entities .= "\"classname\" \"item_invincible\"\n";
	} elsif ($thing->{type} == 2022) {
		$entities .= "\"classname\" \"item_invincible\"\n";
	} elsif ($thing->{type} == 2046 or $thing->{type} == 2010) {
		$entities .= "\"classname\" \"item_rockets\"\n";
	} elsif ($thing->{type} == 2048 or $thing->{type} == 2007) {
		$entities .= "\"classname\" \"item_shells\"\n";
	} elsif ($thing->{type} == 2049 or $thing->{type} == 2008) {
		$entities .= "\"classname\" \"item_bullets\"\n";
	} elsif ($thing->{type} == 2047 or $thing->{type} == 17) {
		$entities .= "\"classname\" \"item_cells\"\n";
	} elsif ($thing->{type} == 2012) {
		$entities .= "\"classname\" \"item_health_medium\"\n";
	} elsif ($thing->{type} == 48 or $thing->{type} == 2028) {
		$entities .= "\"classname\" \"misc_gamemodel\"\n";
		$entities .= "\"model\" \"models/turrets/tesla_head.md3\"\n";
		$entities .= "\"solid\" \"4\"\n";
		$entities .= "\"effects\" \"134217728\"\n";
		$entities .= "\"origin\" \"" . $thing->{x} . " " . $thing->{y} . " " . ($z - 20) . "\"\n";
		$entities .= "}\n";
		$entities .= "{\n";
		$entities .= "\"classname\" \"light\"\n";
		$entities .= "\"light\" \"600\"\n";
	} else {
		print "Unhandled type " . $thing->{type} . "\n";
		$entities .= "\"classname\" \"doom_type" . $thing->{type} . "\"";
	}
	$entities .= "\"angle\" \"" . $thing->{angle} . "\"\n";
	$entities .= "\"origin\" \"" . $thing->{x} . " " . $thing->{y} . " $z\"\n";
	$entities .= "}\n";
}
print $map_file "$entities";
