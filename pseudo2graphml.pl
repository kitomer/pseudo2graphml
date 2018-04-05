#!/usr/bin/perl
# converts pseudo code to .dot and that to .graphml
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
    my %labels; # <label> => <node-id>

    # first run to transform lines into list of elements
    my @elems;
    my $l = 0; # line number
    foreach my $line ( @lines )
    {
        $l++;
        $line =~ s/^[\s\t]*//g;
        $line =~ s/[\s\t\n\r]*$//g;
        next unless length $line;
        #print "{$line}\n";
        my( $kind, $title, $label, $links ) = parse_line( $line, $l, \%labels );
        die "unknown syntax in line $l: $line\n" if $kind eq '';
        push @elems, {  'kind' => $kind, 'id' => mkid(), 'title' => $title, 'label' => $label, 
                        'links' => $links, 'line' => $line, 'linenum' => $l };
    }

    # turn list of elements into deep tree structure
    my $tree = parse( \@elems );
    #dump_tree($tree);
    #die;

    # add implicit nodes and add links
    $tree = transform( $tree );
    add_links( $tree, \%labels );

    # render as list of nodes and edges
    my @nodes;
    my @edges;
    render( $tree, \@nodes, \@edges );
    #print Dumper(\@nodes);
    #print Dumper(\@edges);
    
    close $fh;

    #print Dumper(\@Nodes,\@Edges);
    #die;
    my $graphml = graphml( \@nodes, \@edges );
    if( open( my $fh, '>'.$graphmlfile ) ) {
        print $fh $graphml;
        close $fh;
    }
}

my $idcount = 0;
sub mkid
{
    $idcount ++;
    return 'n'.$idcount;
}

# turns list of elems into structure of BASIC flow
# additional links between nodes added on-the-fly
sub parse
{
    my( $elems ) = @_;

    # add start node if not present
    if( scalar @{$elems} && $elems->[0]->{'kind'} ne 'start' ) {
        unshift @{$elems}, { 'kind' => 'start', 'id' => mkid(), 'title' => 'start', 'label' => '', 
                             'links' => {}, 'line' => '', 'linenum' => -1 };
    }
    
    my $tree = [];
    my @stack = (); # stack with references into $tree
    my $i = 0;
    my $eoe = scalar @{$elems};
    while( $i < $eoe )
    {
        my $e = $elems->[$i];
        #print "{".$e->{'line'}."}\n";
        if( $e->{'kind'} eq 'start' ) {
            # new toplevel node
            $e->{'children'} = [];
            push @{$tree}, $e;
            @stack = ( [ $e, $e->{'children'} ] );
        }
        elsif( $e->{'kind'} eq 'if' ) {
            # new conditional node
            $e->{'children_true'} = [];
            $e->{'children_false'} = [];
            push @stack, [ $e, $e->{'children_true'} ];
        }
        elsif( $e->{'kind'} eq 'elsend' || $e->{'kind'} eq 'end' ) {
            # finish recent conditional node
            push @{$stack[-2]->[1]}, $stack[-1]->[0];
            pop @stack;
        }
        elsif( $e->{'kind'} eq 'else' ) {
            # start else branch of conditional node
            $stack[-1]->[1] = $stack[-1]->[0]->{'children_false'};
        }
        else { # step|noop|finish
            push @{$stack[-1]->[1]}, $e;
        }        
        $i ++;
    }    
    return $tree;
}

sub dump_tree
{
    my( $tree, $ind ) = @_;
    $ind = '' unless defined $ind;
    
    if( ref $tree eq 'ARRAY' ) {
        map { dump_tree( $_, $ind ) } @{$tree};
    }
    else {
        if( $tree->{'kind'} eq 'start' ) {
            print $ind."start\n";
            dump_tree( $tree->{'children'}, $ind.'  ' );
        }
        elsif( $tree->{'kind'} eq 'if' ) {
            print $ind."if\n";
            dump_tree( $tree->{'children_true'}, $ind.'  ' );
            print $ind."else\n";
            dump_tree( $tree->{'children_false'}, $ind.'  ' );
            print $ind."end\n";
        }
        else {
            print $ind.$tree->{'kind'}.': '.$tree->{'title'}."\n";        
        }
    }
}

# add implicit nodes and transform tree structure
sub transform
{
    my( $tree ) = @_;
    # ...
    return $tree;
}

# recursively walk tree, initally call like  walk_tree( $tree, $coderef, $args )
# the coderef is called this way: $coderef->( $treenode, $args, $next_sibling, $next_parent_siblings )
sub walk_tree
{
    my( $tree, $coderef, $args, $next_sibling, $next_parent_siblings ) = @_;
    $next_parent_siblings = [] unless defined $next_parent_siblings;
    if( ref $tree eq 'ARRAY' ) {
        for( my $i = 0; $i < scalar @{$tree}; $i++ ) {
            $next_sibling = ( $i < scalar @{$tree} - 1 ? $tree->[$i+1] : undef );
            walk_tree( $tree->[$i], $coderef, $args, $next_sibling, $next_parent_siblings );
        }
    }
    elsif( ref $tree eq 'HASH' ) {
        if( $tree->{'kind'} eq 'start' ) {
            $coderef->( $tree, $args, undef, undef );
            walk_tree( $tree->{'children'}, $coderef, $args, undef, [ undef ] );
        }
        elsif( $tree->{'kind'} eq 'if' ) {
            $coderef->( $tree, $args, undef, $next_sibling );
            my @sibs = ( @{$next_parent_siblings}, $next_sibling );
            walk_tree( $tree->{'children_true'}, $coderef, $args, undef, \@sibs );
            walk_tree( $tree->{'children_false'}, $coderef, $args, undef, \@sibs );
        }
        else { # step|noop|finish
            $coderef->( $tree, $args, $next_sibling, $next_parent_siblings );
        }
    }
    return 1;
}

sub add_links
{
    my( $tree, $labels ) = @_;
    
    # resolve links in node to the actual node ids
    walk_tree(
        $tree,
        sub {
            my( $node, $args ) = @_;
            my( $labels ) = @{$args};
            my %resolved;
            foreach my $label ( keys %{$node->{'links'}} ) {
                die "unknown label $label\n" unless exists $labels->{$label};
                $resolved{ $labels->{$label} } = $node->{'links'}->{$label};        
            }
            $node->{'links'} = \%resolved;
        },
        [ $labels ]
    );
    # connect nodes for normal flow
    walk_tree(
        $tree,
        sub {
            my( $node, $args, $next_sibling, $next_parent_siblings ) = @_;

            if( $node->{'kind'} eq 'start' ) {
                # connect to first child
                my $first = ( scalar @{$node->{'children'}} ? $node->{'children'}->[0] : undef );
                $node->{'links'}->{ $first->{'id'} } = '' if defined $first;
            }
            elsif( $node->{'kind'} eq 'finish' ) {
                # no link
            }
            elsif( $node->{'kind'} eq 'if' ) {
                # connect with both true and false branch
                my $first_true = ( scalar @{$node->{'children_true'}} ? $node->{'children_true'}->[0] : undef );
                $node->{'links'}->{ $first_true->{'id'} } = $True if defined $first_true;
                my $first_false = ( scalar @{$node->{'children_false'}} ? $node->{'children_false'}->[0] : undef );
                $node->{'links'}->{ $first_false->{'id'} } = $False if defined $first_false;
            }
            else { # step|noop
                if( defined $next_sibling ) {
                    $node->{'links'}->{ $next_sibling->{'id'} } = '';
                }
                elsif( defined $next_parent_siblings ) {
                    # connect to next available parent sibling
                    foreach my $sib ( reverse @{$next_parent_siblings} ) {
                        if( defined $sib ) {
                            $node->{'links'}->{ $sib->{'id'} } = '';
                            last;
                        }
                    }
                }
            }
        },
        [ $labels ]
    );
    return 1;
}

# turn deep structure into list of nodes + edges
sub render
{
    my( $tree, $nodes, $edges ) = @_;
    walk_tree(
        $tree,
        sub {
            my( $node, $args ) = @_;
            my( $nodes, $edges ) = @{$args};
            
            if( $node->{'kind'} eq 'start' || $node->{'kind'} eq 'finish' ) {
                push @{$nodes}, node( $node->{'id'}, $node->{'title'}, 'ellipse' );            
            }
            elsif( $node->{'kind'} eq 'if' ) {
                push @{$nodes}, node( $node->{'id'}, $node->{'title'}, 'diamond' );
            }
            else { # step|noop
                push @{$nodes}, node( $node->{'id'}, $node->{'title'}, 'box' );
            }
            #print "NODE ".$node->{'id'}." (".$node->{'title'}.")\n";
            
            foreach my $link ( keys %{$node->{'links'}} ) {
                #print "LINK ".$node->{'id'}." (".$node->{'title'}.") to $link\n";
                push @{$edges}, edge( $node->{'id'}, $link, $node->{'links'}->{$link} );
            }
        },
        [ $nodes, $edges ]
    );
    return 1;
}

sub parse_line
{
    my( $line, $node_num, $labels ) = @_;
    my $kind = 'step'; # step | if | else | elsend | end | noop | start | finish
    my $title = '';
    my $label = '';
    my %links;
    
    if( $line =~ /\#[0-9a-zA-Z\-\_]+/ ) {
        ( $label ) = $line =~ /^.*\#([0-9a-zA-Z\-\_]+).*$/;
        $labels->{$label} = $node_num;
    }
    if( $line =~ /\-\>[\s\t]*[0-9a-zA-Z\-\_\s\t]+/ ) {
        my( $links ) = $line =~ /^.*?\-\>[\s\t]*([0-9a-zA-Z\-\_\s\t]+).*$/;
        %links = map { ( $_ => '' ) } split /[\s\t]+/, $links;
    }

    ( $kind ) = $line =~ /^(step|if|elsend|else|end|noop|start|finish)/i;
    $kind = ( defined $kind ? lc $kind : 'step' );
    
    $title = $line;
    $title =~ s/\#[0-9a-zA-Z\-\_]+$//;
    $title =~ s/\-\>[\s\t]*[0-9a-zA-Z\-\_\s\t]+//;
    $title =~ s/^(step|elsend|else|end|noop|finish) //;
    $title =~ s/^[\s\t]*//g;
    $title =~ s/[\s\t]*$//g;

    return ( $kind, $title, $label, \%links );
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
    return { 'id' => $num, 'shape' => $shape, 'label' => $label };
}

sub edge
{
    my( $from_num, $to_num, $label ) = @_;
    $label = '' unless defined $label;
    return undef if ! defined $from_num || ! defined $to_num;
    #print "-- LINK $from_num -> $to_num\n";
    return { 'from' => $from_num, 'to' => $to_num, 'label' => $label };
}




