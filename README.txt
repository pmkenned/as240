Author: Paul Kennedy <pmkenned@andrew.cmu.edu>
Last Modified: 3/27/2012

This repository is for the 18-240 assembler. If you make any changes to this script, please test against randomly generated assembly files and at least the provided directed test case to ensure that funtionality is preserved. Please contact me at pmkenned@andrew.cmu.edu regarding any questions, bugs, or changes.

Files:

README.txt:		this file
as240.pl:		the new assembler
asm_gen.pl:		script for generating random, valid assembly files
dtc1.asm:		example of a directed test case which should test all of the error and warning messages
as240_old:      previous assembler, dating back to fall 2011. may be worth
keeping for comparison. Note: must be executed on color machines (e.g.
red.ece.cmu.edu)

Open implementation questions:

* Can a label be on the same line as a .org? (currently allowed)

* Can a label be on its own line? (currently allowed)

* Should I detect invalid constants? e.g. $10J (not currently done)

* Should I insert a "stop" instruction at the end automatically? (currently not done)

* Should labels spelled the same with different case be allowed?

* Should labels always end with a ":"? This would eliminate any confusion between labels and instructions (e.g. a misspelled instruction would not be misinterpreted as a label, there would be no case requirements, etc.)

* Should weird syntax like ,, be interpreted as errors?

* Should I accept both "sta Rs,addr" and "sta addr,Rs", or just the latter? (currently both are supported)

* Should I require that an Rd register be specified for the pop instruction?

* Should I require that the LDA instruction have an addr or can it have two register fields?

BUG: the old assembler for at least the STA instruction only puts the register number in bits 2:0, but not 5:3 as the ISA specifies. (However, it still simulates correctly.)
