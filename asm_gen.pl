#!/usr/bin/perl

# asm_gen.pl: Version 1.3
# Written by Paul Kennedy <pmkenned@andrew.cmu.edu>
# Last updated 1/3/2012
# Generates random, valid assembly files to test as240.pl assembler
# Version 1.3 fixes bug where constants were printed in decimal instead of hex

use strict;
use warnings;

use constant {
	SHORT2 => 0,
	SHORT1 => 1,
	SHORT0 => 2,
	LONG1 => 3,
	LONG0 => 4,
	ORG => 5, # not used...
	DW => 6, # not used...
};

my @instructions = (
#short2
[
	"add",
	"and",
	"cmr",
	"ldr",
	"mov",
	"or",
	"str",
	"sub",
	"xor",
],
 
#short1
[
	"ashr",
	"decr",
	"incr",
	"ldsp",
	"lshl",
	"lshr",
	"neg",
	"not",
	"pop",
	"push",
	"rol",
	"stsp",
],
		 
#short0
[
	"rtn",
	"stop",
],
		 
#long1
[
	"cmi",
	"lda",
	"ldi",
	"ldsf",
	"sta",
	"stsf",
],

#long0
[
	"addsp", # NOTE: comment this line to be compatible with older version of as240 which did not support it
	"bra",
	"brc",
	"brn",
	"brv",
	"brz",
	"jsr",
	".dw", # not really an instruction but same format
	".org", # not really an instruction but same format
#	".equ", # not really an instruction but same format
],
);

open(SOURCE,">rtc1.asm");

my $inst_num = 200;
my $num_labels = int($inst_num/10);
my %label_lines = ();

RAND_LINE: for(my $i=0; $i<$num_labels; $i++) {
	my $rand = int(rand()*$inst_num);
	if(defined $label_lines{$rand}) {
		$i--;
		next RAND_LINE;
	}
	$label_lines{$rand} = 1;
}
my @label_lines_arr = sort {$a <=> $b} keys %label_lines;

my $l=0;
my $org = 0;
my $offset = 0;
for(my $i=0; $i<$inst_num; $i++) {
	my $inst_type = int(rand()*($#instructions+1));
	my $inst_index = int(rand()*($#{$instructions[$inst_type]}+1));
	my $inst = ${$instructions[$inst_type]}[$inst_index];
	my $reg1 = int(rand()*8);
	my $reg2 = int(rand()*8);
	my $const = uc sprintf("%.4x",int(rand()*(1<<15)));
	my $label = int(rand()*3);

	if(defined $label_lines_arr[$l] && $i == $label_lines_arr[$l]) {
		# some of our lines defining labels should be defined with .equ 
		if(int(rand()*10) == 0) {
			print SOURCE "l$l\t.equ\t\$$const\n";
			$l++;
			next;
		}
		# we cannot used a label on the LHS for lines with .org or .dw
		# so try again for a new instr
		if($inst eq '.org' || $inst eq '.dw') {
			$i--;
			next;
		}
		print SOURCE "l$l";
		$l++;
	}

	if($inst_type == SHORT2)
		{print SOURCE "\t$inst\tR$reg1, R$reg2\n"; $offset++;}
	elsif($inst_type == SHORT1) {print SOURCE "\t$inst\tR$reg1\n"; $offset++;}
	elsif($inst_type == SHORT0) {print SOURCE "\t$inst\n"; $offset++;}
	elsif($inst_type == LONG1) {
		if($label == 1) {
			my $label_ref = int(rand()*$num_labels);
			if($inst eq 'sta') {
				print SOURCE "\t$inst\tl$label_ref, R$reg1\n";
			}
			else {
				print SOURCE "\t$inst\tR$reg1, l$label_ref\n";
			}
		}
		else {
			if($inst eq 'sta') {
				print SOURCE "\t$inst\t\$$const,\tR$reg1\n";
			}
			else {
				print SOURCE "\t$inst\tR$reg1, \$$const\n";
			}
		}
		$offset += 2;
	}
	elsif($inst_type == LONG0) {
		if($inst eq ".equ") {
			print SOURCE "\t$inst\t\$$const\n";
		}
		if($label == 1 && ($inst ne ".org")) {
			my $label_ref = int(rand()*$num_labels);
			print SOURCE "\t$inst\tl$label_ref\n";
		}
		else {
			if($inst eq ".org") {
				$const = sprintf("%.4x",$org + $offset + int(rand()*10));
				$org = hex $const;
				$offset = 0;
			}
			print SOURCE "\t$inst\t\$$const\n";
		}
		$offset += 2;
	}
}

close(SOURCE);
