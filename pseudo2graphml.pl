#!/usr/bin/perl
# conversts pseudo code to .dot and that to .graphml
# (open that in yEd then auto-layout it using "flowchart" mode)

use strict;
use warnings;
use Data::Dumper;
use yEd::Document;

my $True = 'Yes';
my $False = 'No';

die "usage: pseudo2graphml <infile> <outfile>\n" if scalar @ARGV < 2;
my( $pseudofile, $graphmlfile ) = @ARGV;

my @Nodes;
my @Edges;

if( open( my $fh, '<'.$pseudofile ) ) {
    my $open_ifs = 0;
    my $open_elses = 0;
    my @lines = <$fh>;

		# find labeled nodes in first run
    my %named; # <label> => <nodename>
		my $i = 1; # node number
		foreach my $line ( @lines )
		{
        $line =~ s/^[\s\t]*//g;
				$line =~ s/[\s\t\n\r]*$//g;
				next unless length $line;

				if( $line =~ /\#[0-9a-zA-Z\-\_]+$/ && $line !~ /^goto/ ) {
            my( $label ) = $line =~ /^.*?\#([0-9a-zA-Z\-\_]+)$/;
            $named{$label} = $i;
        }
        $i++;
		}
		#print Dumper(\%named);

		# create nodes and edges
		my @stack; # elem: [ <block-start-node>, <0=start,1=if,2=else>, <prev-node> ]
		# algo:
		#   - always append to prev node
		#   	- if current block is "if" and prev-node = block-start-node: edge "True"
		#   	- if current block is "else" and prev-node = block-start-node: edge "False"
		#   - if success/error: ?
		my $l = 0; # line number
		$i = 1; # node number
		foreach my $line ( @lines )
		{
				$l++;
        $line =~ s/^[\s\t]*//g;
				$line =~ s/[\s\t\n\r]*$//g;
				next unless length $line;
				#print "{$line}\n";
        
        my $title = $line;
           #$title =~ s/^(else|end|goto)[\s\t]*//;
           $title =~ s/\#[0-9a-zA-Z\-\_]+$//;
				
        if( $line =~ /^start/i ) {
						@stack = ();
						push @stack, [ $i, 0, $i ];
						node( $i, $title, 'ellipse' );
        }
        elsif( $line =~ /^if/i ) {
						node( $i, $title, 'diamond' );
						my $edgelabel = ( $stack[-1]->[1] == 1 ? $True : ( $stack[-1]->[1] == 2 ? $False : '' ) );
						$stack[-1]->[1] = 0 if length $edgelabel;
						edge( $stack[-1]->[2], $i, $edgelabel );
						push @stack, [ $i, 1, $i ];
        }
        elsif( $line =~ /^else/i ) {
						my $if_start_node = $stack[-1]->[0];
						pop @stack;
						push @stack, [ $i, 2, $if_start_node ];
        }
        elsif( $line =~ /^end/i ) {
						pop @stack;
        }
        elsif( $line =~ /^goto/i ) {
						my( $label ) = $line =~ /^goto[\s\t]*\#([0-9a-zA-Z\-\_]+)$/;
						die "unknown label $label at line $l\n" unless exists $named{$label};
						my $edgelabel = ( $stack[-1]->[1] == 1 ? $True : ( $stack[-1]->[1] == 2 ? $False : '' ) );
						$stack[-1]->[1] = 0 if length $edgelabel;
						edge( $stack[-1]->[2], $named{$label}, $edgelabel );
						$stack[-1]->[2] = undef;
        }
        elsif( $line =~ /^error/i ) {
						node( $i, $title, 'ellipse' );
						my $edgelabel = ( $stack[-1]->[1] == 1 ? $True : ( $stack[-1]->[1] == 2 ? $False : '' ) );
						$stack[-1]->[1] = 0 if length $edgelabel;
						edge( $stack[-1]->[2], $i, $edgelabel );
						$stack[-1]->[2] = undef;
        }
        elsif( $line =~ /^success/i ) {
						node( $i, $title, 'ellipse' );
						my $edgelabel = ( $stack[-1]->[1] == 1 ? $True : ( $stack[-1]->[1] == 2 ? $False : '' ) );
						$stack[-1]->[1] = 0 if length $edgelabel;
						edge( $stack[-1]->[2], $i, $edgelabel );
						$stack[-1]->[2] = undef;
				}
        else {
						node( $i, $title );
						my $edgelabel = ( $stack[-1]->[1] == 1 ? $True : ( $stack[-1]->[1] == 2 ? $False : '' ) );
						$stack[-1]->[1] = 0 if length $edgelabel;
						edge( $stack[-1]->[2], $i, $edgelabel );
						$stack[-1]->[2] = $i;
				}
				$i ++;
    }		
    close $fh;
}

#print Dumper(\@Nodes,\@Edges);
#die;
my $graphml = graphml( \@Nodes, \@Edges );
if( open( my $fh, '>'.$graphmlfile ) ) {
	print $fh $graphml;
	close $fh;
}

sub graphml
{
	my( $nodes, $edges ) = @_;
	my $d = yEd::Document->new();

	my %lut; # <nodeid> => <node>
	foreach my $node ( @{$nodes} ) {
		my $shape = ( $node->{'shape'} eq 'box' ? 'rectangle' : $node->{'shape'} );
		my $width = length($node->{'label'}) * 8;
		$width *= ( $node->{'shape'} eq 'diamond' ? 1.2 : 1 );
		my $height = ( $node->{'shape'} eq 'diamond' ? 80 : 40 );
		if( $node->{'label'} =~ /^(error|success|start)$/ ) {
				$width = 70;
				$height = 70;
		}
		my $n = yEd::Node::ShapeNode->new( $node->{'id'}, 'x' => 100, 'y' => 100, 'shape' => $shape, 
																			 'width' => $width, 'height' => $height, 'fillColor' => '#ffffff' );
		my $l = $n->addNewLabel( $node->{'label'} );
		$lut{$node->{'id'}} = $n;
		$d->addNode( $n );
	}
	foreach my $edge ( @{$edges} ) {
		my $e = $d->addNewEdge( 'PolyLineEdge', $lut{$edge->{'from'}}, $lut{$edge->{'to'}}, 'tArrow' => 'standard' );
		my $l = $e->addNewLabel( $edge->{'label'} );
	}
	return $d->buildDocument();
}

sub node
{
		my( $num, $label, $shape ) = @_;
		return '' unless defined $num;
		$label = "Node $num" unless defined $label;
		$shape = 'box' unless defined $shape;
		push @Nodes, { 'id' => 'n'.$num, 'shape' => $shape, 'label' => $label };
		#return '  node [shape="'.$shape.'" label="'.$label.'"]; n'.$num.';'."\n";
		return 1;
}

sub edge
{
		my( $from_num, $to_num, $label ) = @_;
		$label = '' unless defined $label;
		return 0 if ! defined $from_num || ! defined $to_num;
		push @Edges, { 'from' => 'n'.$from_num, 'to' => 'n'.$to_num, 'label' => $label };
		#return '  n'.$from_num.' -> n'.$to_num.( length $label ? ' [label="'.$label.'"]' : '' ).";\n";
		return 1;
}



