package DoomMap;
use strict;
use warnings;

sub load {
	my ($file_name, $lump_num) = @_;
	if (not $lump_num) {
		$lump_num = '';
	}
	my $lumps = {};
	my $wad_file;
	my $map_file;
	my $bytes;
	my ($max_x, $max_y, $min_x, $min_y) = (0, 0, 0, 0);
	print "Opening $file_name\n";
	open $wad_file, '<:raw', $file_name;
	my $bytes_read = read $wad_file, $bytes, 12;
	die("Can't read magic") if $bytes_read < 12;
	my ($magic, $lumps_count, $directory_offset) = unpack 'Z4 I< I<', $bytes;
	print "$magic, $lumps_count, $directory_offset\n";
	seek $wad_file, $directory_offset, 0;
	for (my $i = 0; $i < $lumps_count; $i++) {
		$bytes_read = read $wad_file, $bytes, 16;
		die("Can't read directory item") if $bytes_read < 16;
		my ($lump_offset, $lump_size, $lump_name) = unpack 'I< I< Z8', $bytes;
		print "$lump_name has offset $lump_offset and size $lump_size\n";
		if ($lumps->{$lump_name}) {
			my $i = 1;
			while ($lumps->{$lump_name . $i}) {
				$i++;
			}
			$lump_name .= $i;
		}
		$lumps->{$lump_name} = { offset => $lump_offset, size => $lump_size };
	}
	my $vertexes = $lumps->{'VERTEXES' . $lump_num};
	seek $wad_file, $vertexes->{offset}, 0;
	my $vertexes_count = $vertexes->{size} / 4;
	my $vertexes_data = [];
	for (my $i = 0; $i < $vertexes_count; $i++) {
		$bytes_read = read $wad_file, $bytes, 4;
		die("Can't read vertex data") if $bytes_read < 4;
		my ($x, $y) = unpack 's< s<', $bytes;
		if ($min_x > $x) {
			$min_x = $x;
		}
		if ($min_y > $y) {
			$min_y = $y;
		}
		if ($max_x < $x) {
			$max_x = $x;
		}
		if ($max_y < $y) {
			$max_y = $y;
		}
		print "Vertex: $x $y\n";
		push @{ $vertexes_data }, [$x, $y];
	}
	$vertexes->{data} = $vertexes_data;
	$min_x -= 16;
	$max_x += 16;
	$min_y -= 16;
	$max_y += 16;
	my $nodes = $lumps->{'NODES' . $lump_num};
	seek $wad_file, $nodes->{offset}, 0;
	my $nodes_count = $nodes->{size} / 28;
	my $nodes_data = [];
	for (my $i = 0; $i < $nodes_count; $i++) {
		$bytes_read = read $wad_file, $bytes, 28;
		die("Can't read node data") if $bytes_read < 28;
		my ($x, $y, $dir_x, $dir_y, $rb_top, $rb_bottom, $rb_left, $rb_right, $lb_top, $lb_bottom, $lb_left, $lb_right, $node_right, $node_left) = unpack 's< s< s< s< s< s< s< s< s< s< s< s< S< S<', $bytes;
		print "Node: $x, $y, $dir_x, $dir_y, $rb_top, $rb_bottom, $rb_left, $rb_right, $lb_top, $lb_bottom, $lb_left, $lb_right, $node_right, $node_left\n";
		push @{ $nodes_data }, {x => $x, y => $y, dir_x => $dir_x, dir_y => $dir_y, rb_top => $rb_top, rb_bottom => $rb_bottom, rb_left => $rb_left, rb_right => $rb_right, lb_top => $lb_top, lp_bottom => $lb_bottom, lb_left => $lb_left, lb_right => $lb_right, node_right => $node_right, node_left => $node_left };
	}
	$nodes->{data} = $nodes_data;
	my $sectors = $lumps->{'SECTORS' . $lump_num};
	seek $wad_file, $sectors->{offset}, 0;
	my $sectors_count = $sectors->{size} / 26;
	my $sectors_data = [];
	for (my $i = 0; $i < $sectors_count; $i++) {
		$bytes_read = read $wad_file, $bytes, 26;
		die("Can't read sector data") if $bytes_read < 26;
		my ($floor_z, $ceil_z, $floor_tex, $ceil_tex, $light, $special, $tag) = unpack 's< s< Z8 Z8 s< S< S<', $bytes;
		print "Sector: $floor_z, $ceil_z, $floor_tex, $ceil_tex, $light, $special, $tag\n";
		push @{ $sectors_data }, { floor_tex => $floor_tex, floor_z => $floor_z, ceil_tex => $ceil_tex, ceil_z => $ceil_z, light => $light, special => $special, tag => $tag };
	}
	$sectors->{data} = $sectors_data;
	my $sidedefs = $lumps->{'SIDEDEFS' . $lump_num};
	seek $wad_file, $sidedefs->{offset}, 0;
	my $sidedefs_count = $sidedefs->{size} / 30;
	my $sidedefs_data = [];
	for (my $i = 0; $i < $sidedefs_count; $i++) {
		$bytes_read = read $wad_file, $bytes, 30;
		die("Can't read linedef data") if $bytes_read < 30;
		my ($x_offset, $y_offset, $upper, $lower, $middle, $sector) = unpack 's< s< Z8 Z8 Z8 S<', $bytes;
		print "Sidedefs: $x_offset, $y_offset, $upper, $lower, $middle, $sector\n";
		if ($sector < $sectors_count) {
			$sector = $sectors_data->[$sector];
		} else {
			$sector = {};
		}
		push @{ $sidedefs_data }, { x_offset => $x_offset, y_offset => $y_offset, upper => $upper, lower => $lower, middle => $middle, sector => $sector };
	}
	$sidedefs->{data} = $sidedefs_data;
	my $linedefs = $lumps->{'LINEDEFS' . $lump_num};
	seek $wad_file, $linedefs->{offset}, 0;
	my $linedefs_count = $linedefs->{size} / 14;
	my $linedefs_data = [];
	for (my $i = 0; $i < $linedefs_count; $i++) {
		$bytes_read = read $wad_file, $bytes, 14;
		die("Can't read linedef data") if $bytes_read < 14;
		my ($v1, $v2, $flags, $type, $sector_tag, $right_def, $left_def) = unpack 'S< S< S< S< S< S< S<', $bytes;
		print "Linedef: $v1, $v2, $flags, $type, $sector_tag, $right_def, $left_def\n";
		if ($right_def < $sidedefs_count) {
			$right_def = $sidedefs_data->[$right_def];
		} else {
			$right_def = {};
		}
		if ($left_def < $sidedefs_count) {
			$left_def = $sidedefs_data->[$left_def];
		} else {
			$left_def = {};
		}
		push @{ $linedefs_data }, { v1 => $vertexes_data->[$v1], v2 => $vertexes_data->[$v2], flags => $flags, type => $type, sector_tag => $sector_tag, right_def => $right_def, left_def => $left_def };
	}
	$linedefs->{data} = $linedefs_data;
	my $things = $lumps->{'THINGS' . $lump_num};
	seek $wad_file, $things->{offset}, 0;
	my $things_count = $things->{size} / 10;
	my $things_data = [];
	for (my $i = 0; $i < $things_count; $i++) {
		$bytes_read = read $wad_file, $bytes, 10;
		die("Can't read linedef data") if $bytes_read < 10;
		my ($x, $y, $angle, $type, $flags) = unpack 's< s< S< S< S<', $bytes;
		print "Thing: $x, $y, $angle, $type, $flags\n";
		push @{ $things_data }, { x => $x, y => $y, angle => $angle, type => $type, flags => $flags };
	}
	$things->{data} = $things_data;
	my $subsectors = $lumps->{'SSECTORS' . $lump_num};
	seek $wad_file, $subsectors->{offset}, 0;
	my $subsectors_count = $subsectors->{size} / 4;
	my $subsectors_data = [];
	for (my $i = 0; $i < $subsectors_count; $i++) {
		$bytes_read = read $wad_file, $bytes, 4;
		die("Can't read subsector data") if $bytes_read < 4;
		my ($count, $offset) = unpack 'S< S<', $bytes;
		print "Subsector: $count, $offset\n";
		push @{ $subsectors_data }, { count => $count, offset => $offset };
	}
	$subsectors->{data} = $subsectors_data;
	my $segments = $lumps->{'SEGS' . $lump_num};
	seek $wad_file, $segments->{offset}, 0;
	my $segments_count = $segments->{size} / 12;
	my $segments_data = [];
	for (my $i = 0; $i < $segments_count; $i++) {
		$bytes_read = read $wad_file, $bytes, 12;
		die("Can't read segment data") if $bytes_read < 12;
		my ($v1, $v2, $angle, $linedef, $direction, $offset) = unpack 'S< S< s< S< s< s<', $bytes;
		print "Segment: $v1, $v2, $angle, $linedef, $direction, $offset\n";
		push @{ $segments_data }, { v1 => $vertexes_data->[$v1], v2 => $vertexes_data->[$v2], angle => $angle, linedef => $linedefs_data->[$linedef], direction => $direction, offset => $offset };
	}
	$segments->{data} = $segments_data;
	my $min_z = $sectors_data->[0]->{floor_z};
	my $max_z = $sectors_data->[0]->{ceil_z};
	foreach my $sector(@{ $sectors_data }) {
		if ($sector->{floor_z} < $min_z) {
			$min_z = $sector->{floor_z};
		}
		if ($sector->{ceil_z} > $max_z) {
			$max_z = $sector->{ceil_z};
		}
	}
	$min_z -= 16;
	$max_z += 16;
	return {
			min_z => $min_z,
			max_z => $max_z,
			min_x => $min_x,
			max_x => $max_x,
			min_y => $min_y,
			max_y => $max_y,
			vertexes => $vertexes_data,
			linedefs => $linedefs_data,
			segments => $segments_data,
			nodes => $nodes_data,
			things => $things_data,
			subsectors => $subsectors_data,
			sectors => $sectors_data};
}
sub sector_neigbours {
	my ($doom_map, $sector) = @_;
	my $neighbours = [];
	foreach my $line(@{ $doom_map->{linedefs} }) {
		if (not %{ $line->{left_def} } or not %{ $line->{right_def} }) {
			next; #no need for one sided
		}
		if (not %{ $line->{left_def}->{sector} } or not %{ $line->{right_def}->{sector} }) {
			next; #no need for one sided
		}
		if ($line->{left_def}->{sector} == $sector) {
			push @{ $neighbours }, $line->{right_def}->{sector};
		} elsif ($line->{right_def}->{sector} == $sector) {
			push @{ $neighbours }, $line->{left_def}->{sector};
		}
	}
	return $neighbours;
}
sub line_dot_det {
	my ($v1, $v2, $v) = @_;
	return ($v2->[0] - $v1->[0]) * ($v->[1] - $v1->[1]) - ($v2->[1] - $v1->[1]) * ($v->[0] - $v1->[0]);
}
sub sector_search {
	my ($map, $x, $y) = @_;
	my $next_node = @{ $map->{nodes} } - 1;
	my $node = $map->{nodes}->[$next_node];
	my $side;
	my $subsec;
	while (1) {
		#print "Processing node $next_node\n";
		$side = &line_dot_det([$node->{x}, $node->{y}], [$node->{x} + $node->{dir_x}, $node->{y} + $node->{dir_y}], [$x, $y]);
		if ($side < 0) {
			#print "Right\n";
			$next_node = $node->{node_right};
		} else {
			#print "Left\n";
			$next_node = $node->{node_left};
		}
		if ($next_node & 32768) {
			#print "Subsector\n";
			$next_node = $next_node & 32767;
			if ($next_node >= scalar @{ $map->{subsectors} }) {
				print("Wrong subsector offset\n");
				return {};
			}
			$subsec = $map->{subsectors}->[$next_node];
			last;
		} else {
			#print "Node\n";
			if ($next_node >= scalar @{ $map->{nodes} }) {
				print("Wrong node offset\n");
				return {};
			}
			$node = $map->{nodes}->[$next_node];
		}
	}
	my $seg = $map->{segments}->[$subsec->{offset}];
	my $linedef = $seg->{linedef};
	my $sector;
	if ($seg->{direction}) {
		$sector = $linedef->{left_def}->{sector};
	} else {
		$sector = $linedef->{right_def}->{sector};
	}
	return $sector;
}

1;
