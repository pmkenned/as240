#!/usr/bin/perl

use strict;
use warnings;

# TODO:
# * add words to the list file
# * handle sta instruction

# types of errors:
# * overlapping org regions
# * parse errors (e.g. expecting 2 regs, saw 1)
# * forgetting whitespace
# * forgetting $ in front of constants

my $version = '2.0';

# instructions which consume 1 word and require two register fields (Rs and Rd)
my %short2 = (
                'add' =>    0x0E00,
                'and' =>    0x1A00,
                'cmr' =>    0x4600,
                'ldr' =>    0x0800,
                'mov' =>    0x3A00,
                'or'  =>    0x1C00,
                'str' =>    0x0A00,
                'sub' =>    0x1000,
                'xor' =>    0x1E00,
            );

# instructions which consume 1 word and require 1 register field (Rd)
my %short1 = (
                'ashr' =>    0x2600,
                'decr' =>    0x1600,
                'incr' =>    0x1400,
                'ldsp' =>    0x3C00,
                'lshl' =>    0x2000,
                'lshr' =>    0x2400,
                'neg'  =>    0x1200,
                'not'  =>    0x1800,
                'pop'  =>    0x3400,
                'push' =>    0x3200,
                'rol'  =>    0x2200,
                'stsp' =>    0x3E00,
            );

# instructions which consume 1 word and require 0 register fields
my %short0 = (
                'rtn'  =>    0x3800,
                'stop' =>    0x3000,
            );

# instructions which consume 2 words and require 1 register field
my %long1 = (
                'cmi'  =>    0x4400,
                'lda'  =>    0x0400,
                'ldi'  =>    0x0C00,
                'ldsf' =>    0x4000,
                'sta'  =>    0x0600,
                'stsf' =>    0x4200,
            );

# instructions which consume 2 words and require 0 register field
my %long0 = (
                'addsp' =>    0x0f00,
                'bra'   =>    0x2800,
                'brc'   =>    0x4800,
                'brn'   =>    0x2C00,
                'brv'   =>    0x2E00,
                'brz'   =>    0x2A00,
                'jsr'   =>    0x3600,
            );


my %g_labels;     # keys: label names. values: resolved address value.
my %g_label_refs; # records places where labels are referenced. keys: addresses. values: label name.
my %g_memory;     # result of assembly. keys: address. value: assembled hex value.

main();

sub usage {
    die "as240 verion $version\nUsage : as240 <input file name>" unless(defined $ARGV[0]);
}

sub main {

    my $argc = $#ARGV+1;
    if($argc < 2) {
        usage();
    }

    ($ARGV[0] =~ /(.+)\.asm$/) or die "invalid filename; must end in '.asm'";
    my $filename = $1;

    open(my $source_fh, "<", $ARGV[0]) or die $!;
    my @lines = <$source_fh>;      # slurp assembly source
    close $source_fh;

    s/\;.*//g foreach (@lines);    # strip comments

    my $org = 0;    # updated by .org pseudo-instr
    my $offset = 0;

    my $line_num = 0;
    my $num_errors = 0;
    LINE: foreach my $line (@lines) {
        chomp $line;
        $line_num++;

        my @tokens = get_tokens($line);

        my %line_data = parse(@tokens);

        if(exists $line_data{error}) {
            my $error_str = $line_data{error};
            print "error on line $line_num: $error_str\n";
            print $line . "\n";
            $num_errors++;
            next LINE;
        }

        my %trans = translate(%line_data);

        # stash the translation into memory
        write_to_mem($org+$offset, $trans{word0}) if(exists $trans{word0});
        write_to_mem($org+$offset+1, $trans{word1}) if(exists $trans{word1});

        # record the labels that are defined and referenced on this line
        store_labels($org, $offset, %line_data);

        # calculate next address
        if(exists $line_data{pseudo} and $line_data{pseudo} =~ /org/) {
            $org = hex $line_data{const};
            $offset = 0;
        }
        else {
            $offset += 1 if(exists $trans{word0});
            $offset += 1 if(exists $trans{word1});
        }
    }

    fill_in_labels();

    if($num_errors == 0) {
        write_list_file($filename . '.list');
    }
    else {
        print "assembly failed with $num_errors errors\n";
    }

}

sub write_to_mem {
    my $addr = shift;
    my $data = shift;
    if(exists $g_memory{$addr}) {
        print "error: overlapping org region at $addr\n";
    }
    else {
        $g_memory{$addr} = $data;
    }
}

sub write_list_file {
    my $filename = shift;

    open(my $list_fh, ">", $filename) or die $!;
    foreach my $addr (sort keys %g_memory) {
        printf $list_fh ("%04x: %04x\n", $addr, $g_memory{$addr});
    }
    close($list_fh);
}

# now that the value of every label is known, we can fill in all the
# places where labels are referenced with their known values
# TODO: consider including line number with the reference so that 
# a line number can be printed for undefined labels
sub fill_in_labels {
    foreach my $ref_addr (keys %g_label_refs) {
        my $label = $g_label_refs{$ref_addr};
        if(exists $g_labels{$label}) {
            $g_memory{$ref_addr} = $g_labels{$label};
        }
        else {
            print "error: label $label is undefined\n";
        }
    }
}

# handles the recording of label definitions and references
sub store_labels {
    my $org = shift;
    my $offset = shift;
    my %line_data = @_;

    # record label definitions
    if(exists $line_data{label_def}) {
        my $label = $line_data{label_def};
        my $equ_def = (exists $line_data{pseudo} and $line_data{pseudo} =~ /equ/);
        my $target;
        if($equ_def) {
            $target = hex $line_data{const};
        }
        else {
            $target = $org + $offset;
        }
        if(exists $g_labels{$label}) {
            print "error: label $label already defined\n";
        }
        else {
            $g_labels{$label} = $target;
        }
    }

    # record label references
    if(exists $line_data{label_ref}) {
        my $label = $line_data{label_ref};
        $g_label_refs{$org+$offset+1} = $label;
    }
}

# generate the assembly hex value by examining a hash
# based on the following keys: inst, rd, rs, const, pseudo
# some keys might not be present depending on the line of code
sub translate {
    my %hash = @_;
    my %translation;

    my ($word0, $word1);
    my ($rd, $rs);
    my ($inst);

    if(exists $hash{inst}) {
        $rd = $hash{rd};
        $rs = $hash{rs};
        $inst = $hash{inst};
        $word0 = inst_to_hex($inst) | ($rd << 3) | $rs;
        if(word_is_inst($inst) =~ /L/) {
            $word1 = hex $hash{const};
        }
    }
    elsif(exists $hash{pseudo}) {
        if($hash{pseudo} =~ /dw/) {
            $word0 = hex $hash{const};
        }
    }

    $translation{word0} = $word0 if defined $word0;
    $translation{word1} = $word1 if defined $word1;

    return %translation;
}

# takens a list of tokens and returns a hash with the relevant information
# example: if the line was "l0 add r0, r1", the hash will have
# the following keys/value pairs: label_def => l0, inst=>add, rd=>r0, rs=>r1
# this makes it very easy to translate the line without having to keep track
# of the order of the tokens. Instead, just see if a certain key is in the hash.
sub parse {
    my @tokens = @_;
    my %line_data = ();
    my $token_str = get_token_str(@tokens);

    # check for common errors
    my $error_str = common_parse_errors($token_str);
    if($error_str ne '') {
        $line_data{error} = $error_str;
        return %line_data;
    }

    # check for a valid form
    my $valid = 0;
    if( ($token_str =~ /^d?(S2rr|S1r|S0)$/) or
        ($token_str =~ /^d?(L1r|L0)[cl]$/) or
        ($token_str =~ /^d?p[lc]$/)) {
        $valid = 1;
    }
    # if not a valid form, return generic error message
    if(!$valid) {
        $line_data{error} = "parse error";
        return %line_data;
    }

    # we can assume a valid input line from this point forward

    foreach my $token (@tokens) {
        my $tok_type = $token->{type};
        my $tok_value = $token->{value};
        if($tok_type eq 'l') {
            $line_data{label_ref} = $tok_value;
        }
        elsif($tok_type eq 'd') {
            $line_data{label_def} = $tok_value;
        }
        elsif($tok_type eq 'r') {
            if(!exists $line_data{rd}) {
                $line_data{rd} = $tok_value;
                $line_data{rs} = $tok_value;
            }
            else {
                $line_data{rs} = $tok_value;
            }
        }
        elsif($tok_type eq 'c') {
            $line_data{const} = $tok_value;
        }
        elsif($tok_type =~ /(L|S)/) {
            $line_data{inst} = $tok_value;
        }
        elsif($tok_type =~ /p/) {
            $line_data{pseudo} = $tok_value;
        }
    }

    $line_data{const} = 0 if(!exists $line_data{const});
    $line_data{rd} = 0    if(!exists $line_data{rd});
    $line_data{rs} = 0    if(!exists $line_data{rs});

    return %line_data;
}

sub common_parse_errors {
    my $token_str = shift;
    my $error_str = '';
    # common invalid forms
    if($token_str =~ /^d?S2(r?|r{3,}|r[cl])$/) {
        $error_str = "instruction expected two registers";
    }
    elsif($token_str =~ /^d?S1(|r{2,}|[cl])$/) {
        $error_str = "instruction expected one register";
    }
    elsif($token_str =~ /^d?S0(r+|[cl])$/) {
        $error_str = "instruction expected zero registers";
    }
    elsif($token_str =~ /^d?L1(|r{2,})c$/) {
        $error_str = "instruction expected one register";
    }
    elsif($token_str =~ /^d?L0r+c$/) {
        $error_str = "instruction expected zero registers";
    }
    elsif($token_str =~ /^d?L1r$/) {
        $error_str = "instruction expected constant";
    }
    return $error_str;
}

# creates a terse string based on the sequence tokens in a line
# it is easy to check for parse errors using regex on this string
sub get_token_str {
    my @tokens = @_;
    my $token_str = '';

    foreach my $token (@tokens) {
        my $type = $token->{type};
        my $value = $token->{value};
        $token_str .= $type;
    }

    return $token_str;
}

# input: a string containing a line of assembly code
# output: an array of hashes, each of which contain two key-value pairs:
#         * type => string indicating the type of token
#         * value => the substring for this token
# 
sub get_tokens {

    my $line = shift;

    my @words = split /\s/, $line;
    my $num_words = $#words + 1;

    my @tokens = ();

    my $first_word = 1;
    foreach my $word (@words) {
        my $inst_type = word_is_inst($word);

        if($first_word and $line =~ /^([a-zA-Z_]\w*)/) {
            push @tokens, {type => "d", value => $word};
        }
        elsif($word =~ /^[rR]([0-7]),?$/) {
            push @tokens, {type => "r", value => $1};
        }
        elsif($inst_type) {
            push @tokens, {type => $inst_type, value => $word};
        }
        elsif($word =~ /^[a-zA-Z_]\w*,?$/) {
            push @tokens, {type => "l", value => $word};
        }
        elsif($word =~ /^\.\w+$/) {
            push @tokens, {type => "p", value => $word};
        }
        elsif($word =~ /^\$([0-9A-Fa-f]{1,4}),?$/) {
            push @tokens, {type => "c", value => $1};
        }
        elsif($word eq '') {
        }
        else {
            print "error: unmatched token '$word'\n";
        }

        $first_word = 0;
    }

    return @tokens;
}

sub inst_to_hex {
    my $inst = shift;
    my $inst_hex;
    $inst_hex = $short2{$inst} if exists $short2{$inst};
    $inst_hex = $short1{$inst} if exists $short1{$inst};
    $inst_hex = $short0{$inst} if exists $short0{$inst};
    $inst_hex = $long1{$inst} if exists $long1{$inst};
    $inst_hex = $long0{$inst} if exists $long0{$inst};
    return $inst_hex;
}

sub word_is_inst {
    my $key = shift;
    my $rv = 0;
    $rv = 'S2' if exists $short2{$key};
    $rv = 'S1' if exists $short1{$key};
    $rv = 'S0' if exists $short0{$key};
    $rv = 'L1' if exists $long1{$key};
    $rv = 'L0' if exists $long0{$key};
    return $rv;
}
