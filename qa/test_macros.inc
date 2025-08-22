
.macro CHECK_EQUAL
.scope
  beq pass
  jsr error
pass:
.ends
.endm

.macro CHECK_NOT_EQUAL
.scope
  bne pass
  jsr error
pass:
.ends
.endm

.macro CHECK_ZERO
.scope
  beq pass
  jsr error
pass:
.ends
.endm

.macro CHECK_NOT_ZERO
.scope
  bne pass
  jsr error
pass:
.ends
.endm

