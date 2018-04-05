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

if( open( my $fh, '<'.$pseudofile ) )
{
    my $open_ifs = 0;
    my $open_elses = 0;
    my @lines = <$fh>;

    # find labeled nodes in first run
    my %named; # <label> => <node-num>

    # first run to transform lines into list of elements
    my @elems;
    my $l = 0; # line number
    my $n = 0; # node number
    foreach my $line ( @lines )
    {
        $l++;
        $line =~ s/^[\s\t]*//g;
        $line =~ s/[\s\t\n\r]*$//g;
        next unless length $line;
        #print "{$line}\n";
        my( $kind, $title, $label, $links ) = parse_line( $line, $n, \%named );
        die "unknown syntax in line $l: $line\n" if $kind eq '';
        push @elems, {  'kind' => $kind, 'num' => $n, 'title' => $title, 'label' => $label, 
                        'links' => $links, 'line' => $line, 'linenum' => $l };
        $n++;
    }
    
    # second run for transforming and/or creating implicit nodes
    
    # add start node if not present
    if( scalar @elems ) {
        if( $elems[0]->{'kind'} ne 'start' ) {
            push @elems, {  'kind' => 'start', 'num' => $n, 'title' => 'start', 'label' => '', 
                            'links' => [], 'line' => '', 'linenum' => -1 };
            $n++;
        }
    }
    my @elems_transformed;
    my $label = 1; # unique label
    my $e = 0;
    for( my $e = 0; $e < scalar @elems; $e++ )
    {
        my $elem = $elems[$e];
        if( $elem->{'kind'} eq 'elsend' ) {

#            if( $e < scalar @elems - 1 ) {
#                my $next = $elems[$e+1];
#                push @elems_transformed, {  'kind' => 'else', 'num' => $n, 'title' => '', 'label' => '', 
#                                            'links' => [], 'line' => '', 'linenum' => -1 };
#                $n++;
#                unless( length $next->{'label'} ) {
#                    $next->{'label'} = 'unique-'.$label;
#                    $named{$next->{'label'}} = $next->{'num'};
#                    $label ++;
#                }
#                push @elems_transformed, {  'kind' => 'noop', 'num' => $n, 'title' => '', 'label' => '', 
#                                            'links' => [ $next->{'label'} ], 'line' => '', 'linenum' => -1 };
#                $n++;
#                push @elems_transformed, {  'kind' => 'end', 'num' => $n, 'title' => '', 'label' => '', 
#                                            'links' => [], 'line' => '', 'linenum' => -1 };
#                $n++;
#            }
        
            push @elems_transformed, {  'kind' => 'else', 'num' => $n, 'title' => '', 'label' => '', 
                                        'links' => [], 'line' => '', 'linenum' => -1 };
            $n++;
            push @elems_transformed, {  'kind' => 'noop', 'num' => $n, 'title' => '', 'label' => '', 
                                        'links' => [ 'unique-'.$label ], 'line' => '', 'linenum' => -1 };
            $n++;
            push @elems_transformed, {  'kind' => 'end', 'num' => $n, 'title' => '', 'label' => '', 
                                        'links' => [], 'line' => '', 'linenum' => -1 };
            $n++;
            push @elems_transformed, {  'kind' => 'noop', 'num' => $n, 'title' => '', 'label' => 'unique-'.$label, 
                                        'links' => [], 'line' => '', 'linenum' => -1 };
            $named{'unique-'.$label} = $n;
            $n++;
            $label ++;
        }
        else {
            push @elems_transformed, $elem;
        }
    }
    #print Dumper(\@elems_transformed);
    #die;
    
    # third run for creating nodes and edges
    my @stack; # elem: [ <block-start-node>, <0=start,1=if,2=else>, <prev-node> ]
    my @Nodes;
    my @Edges;
    foreach my $elem ( @elems_transformed )
    {
        if( $elem->{'kind'} eq 'start' ) {
            @stack = ();
            push @stack, [ $elem->{'num'}, 0, $elem->{'num'} ];
            push @Nodes, node( $elem->{'num'}, $elem->{'title'}, 'ellipse' );
        }
        elsif( $elem->{'kind'} eq 'if' ) {
            push @Nodes, node( $elem->{'num'}, $elem->{'title'}, 'diamond' );
            my $edgelabel = ( $stack[-1]->[1] == 1 ? $True : ( $stack[-1]->[1] == 2 ? $False : '' ) );
            $stack[-1]->[1] = 0 if length $edgelabel;
            push @Edges, edge( $stack[-1]->[2], $elem->{'num'}, $edgelabel );
            push @stack, [ $elem->{'num'}, 1, $elem->{'num'} ];
        }
        elsif( $elem->{'kind'} eq 'else' ) {
            my $if_start_node = $stack[-1]->[0];
            pop @stack;
            push @stack, [ $elem->{'num'}, 2, $if_start_node ];
        }
        elsif( $elem->{'kind'} eq 'end' ) {
            # BUG: stuff after the "end" is connected to the wrong node...
            pop @stack;
        }
#        elsif( $elem->{'kind'} eq 'goto' ) {
#            my( $label ) = $line =~ /^goto[\s\t]*\#([0-9a-zA-Z\-\_]+)$/;
#            die "unknown label $label at line $l\n" unless exists $named{$label};
#            my $edgelabel = ( $stack[-1]->[1] == 1 ? $True : ( $stack[-1]->[1] == 2 ? $False : '' ) );
#            $stack[-1]->[1] = 0 if length $edgelabel;
#            edge( $stack[-1]->[2], $named{$label}, $edgelabel );
#            $stack[-1]->[2] = undef;
#        }
        elsif( $elem->{'kind'} eq 'error' ) {
            push @Nodes, node( $elem->{'num'}, $elem->{'title'}, 'ellipse' );
            my $edgelabel = ( $stack[-1]->[1] == 1 ? $True : ( $stack[-1]->[1] == 2 ? $False : '' ) );
            $stack[-1]->[1] = 0 if length $edgelabel;
            push @Edges, edge( $stack[-1]->[2], $elem->{'num'}, $edgelabel );
            $stack[-1]->[2] = undef;
        }
        elsif( $elem->{'kind'} eq 'success' ) {
            push @Nodes, node( $elem->{'num'}, $elem->{'title'}, 'ellipse' );
            my $edgelabel = ( $stack[-1]->[1] == 1 ? $True : ( $stack[-1]->[1] == 2 ? $False : '' ) );
            $stack[-1]->[1] = 0 if length $edgelabel;
            push @Edges, edge( $stack[-1]->[2], $elem->{'num'}, $edgelabel );
            $stack[-1]->[2] = undef;
        }
        elsif( $elem->{'kind'} eq 'step' ) {
            push @Nodes, node( $elem->{'num'}, $elem->{'title'}, );
            my $edgelabel = ( $stack[-1]->[1] == 1 ? $True : ( $stack[-1]->[1] == 2 ? $False : '' ) );
            $stack[-1]->[1] = 0 if length $edgelabel;
            push @Edges, edge( $stack[-1]->[2], $elem->{'num'}, $edgelabel );
            $stack[-1]->[2] = $elem->{'num'};
        }
        elsif( $elem->{'kind'} eq 'noop' ) {
            push @Nodes, node( $elem->{'num'}, '', 'ellipse' );
            my $edgelabel = ( $stack[-1]->[1] == 1 ? $True : ( $stack[-1]->[1] == 2 ? $False : '' ) );
            $stack[-1]->[1] = 0 if length $edgelabel;
            push @Edges, edge( $stack[-1]->[2], $elem->{'num'}, $edgelabel );
            $stack[-1]->[2] = $elem->{'num'};
        }
        
        foreach my $to_label ( @{$elem->{'links'}} ) {
            die "unknown label ".$to_label."\n" unless exists $named{$to_label};
            push @Edges, edge( $elem->{'num'}, $named{$to_label} );
        }
    }        
    # create additional arbitrary links between labeled nodes
    #foreach my $from_num ( keys %edges ) {
    #    foreach my $to_label ( keys %{$edges{$from_num}} ) {
    #        die "unknown label ".$to_label."\n" unless exists $named{$to_label};
    #        push @Edges, edge( $from_num, $named{$to_label} );
    #    }
    #}
    #print Dumper(\%edges);
    #die;
    #print Dumper(\%named);
    
    close $fh;

    #print Dumper(\@Nodes,\@Edges);
    #die;
    my $graphml = graphml( \@Nodes, \@Edges );
    if( open( my $fh, '>'.$graphmlfile ) ) {
        print $fh $graphml;
        close $fh;
    }
}

sub parse_line
{
    my( $line, $node_num, $named ) = @_;
    my $kind = 'step'; # step | if | else | elsend | end | noop | start | error | success
    my $title = '';
    my $label = '';
    my @links;
    
    if( $line =~ /\#[0-9a-zA-Z\-\_]+/ ) {
        ( $label ) = $line =~ /^.*\#([0-9a-zA-Z\-\_]+).*$/;
        $named->{$label} = $node_num;
    }
    if( $line =~ /\-\>[\s\t]*[0-9a-zA-Z\-\_\s\t]+/ ) {
        my( $links ) = $line =~ /^.*?\-\>[\s\t]*([0-9a-zA-Z\-\_\s\t]+).*$/;
        @links = split /[\s\t]+/, $links;
        #map {
        #    $edges->{$node_num} = {} unless exists $edges->{$node_num};
        #    $edges->{$node_num}->{$_} = 1;
        #} @links;
    }

    ( $kind ) = $line =~ /^(step|if|elsend|else|end|noop|start|error|success)/i;
    $kind = ( defined $kind ? lc $kind : 'step' );
    
    $title = $line;
    $title =~ s/\#[0-9a-zA-Z\-\_]+$//;
    $title =~ s/\-\>[\s\t]*[0-9a-zA-Z\-\_\s\t]+//;
    $title =~ s/^(step|elsend|else|end|noop) //;
    $title =~ s/^[\s\t]*//g;
    $title =~ s/[\s\t]*$//g;

    return ( $kind, $title, $label, \@links );
}

sub graphml
{
    my( $nodes, $edges ) = @_;
    my $d = yEd::Document->new();

    my %lut; # <nodeid> => <node>
    foreach my $node ( @{$nodes} )
    {
        next unless defined $node;
        my $shape = ( $node->{'shape'} eq 'box' ? 'rectangle' : $node->{'shape'} );
        my $width = length($node->{'label'}) * 8;
        $width *= ( $node->{'shape'} eq 'diamond' ? 1.2 : 1 );
        my $height = ( $node->{'shape'} eq 'diamond' ? 80 : 40 );
        if( ! length $node->{'label'} ) {
            $width = 1;
            $height = 1;
        }
        elsif( $node->{'label'} =~ /^(error|success|start)$/ ) {
            $width = 70;
            $height = 70;
        }
        my $n = yEd::Node::ShapeNode->new( $node->{'id'}, 'x' => 100, 'y' => 100, 'shape' => $shape, 
                                                                             'width' => $width, 'height' => $height, 'fillColor' => '#ffffff' );
        my $l = $n->addNewLabel( $node->{'label'} );
        $lut{$node->{'id'}} = $n;
        $d->addNode( $n );
    }
    foreach my $edge ( @{$edges} )
    {
        next unless defined $edge;
        #next unless defined $lut{$edge->{'from'}};
        #next unless defined $lut{$edge->{'to'}};
        my $e = $d->addNewEdge( 'PolyLineEdge', $lut{$edge->{'from'}}, $lut{$edge->{'to'}}, 'tArrow' => 'standard' );
        my $l = $e->addNewLabel( $edge->{'label'} );
    }
    return $d->buildDocument();
}

sub node
{
    my( $num, $label, $shape ) = @_;
    return undef unless defined $num;
    $label = "Node $num" unless defined $label;
    $shape = 'box' unless defined $shape;
    return { 'id' => 'n'.$num, 'shape' => $shape, 'label' => $label };
}

sub edge
{
    my( $from_num, $to_num, $label ) = @_;
    $label = '' unless defined $label;
    return undef if ! defined $from_num || ! defined $to_num;
    return { 'from' => 'n'.$from_num, 'to' => 'n'.$to_num, 'label' => $label };
}






