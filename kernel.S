.globl boot

.section .rodata
hello: .ascii "Hello, world\n"

.text

boot:
  auipc a0, %pcrel_hi(hello)
  addi a0, a0, %lo(hello)
  jal ra, sbi_printer
  wfi
spin:
  jal x0, spin


sbi_printer:
  mv t1, a0
  li t2, 0
  mv t3, ra
loop:
  lw a0, 0(t1)
  beq a0, t2, loop_end
  jal ra, sbi_putchar
  addi t1, t1, 1
  jal x0, loop
loop_end:
  mv ra, t3
  ret


sbi_putchar:
  li a1, 0
  li a2, 0
  li a3, 0
  li a4, 0
  li a5, 0
  li a6, 0
  li a7, 1
  ecall
  ret
