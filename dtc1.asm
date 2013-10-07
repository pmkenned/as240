	.org			; should generate ERR_ORG_CONST
	.dw				; should generate ERR_DW_CONST
	.equ			; should generate ERR_EQU_CONST
foo	bar				; should generate ERR_INVALID_INST
	incr			; should generate ERR_EXPECTED_REG
foo	ldi r0, $100	; should generate ERR_REPEAT_LABEL
	lda r0, bar		; should generate ERR_UNDEFINED_LABEL
	.foo			; should generate ERR_DIRECTIVE
	stop blah		; should generate ERR_TRAILING
fum	.org $100		; should generate WARN_LABEL_ORG
	lda r0, r2		; should generate WARN_REG_NUM and ERR_UNDEFINED_LABEL
	lda r0			; should generate ERR_MISSING_OPERAND
	.org $0			; should generate ERR_ORG_OVERLAP
	add r0, r9		; should generate ERR_INVALID_REG
