# emits the symbol name 'boot' to the GLOBAL symbol table so
# that it is visible to linker
.globl boot

# this creates a section '.rodata' in the output file it not already present
# and makes .rodata section the current section. meaning everything below this
# will be put to .rodata section until another directive that changes the section
.section .rodata
hello: .string "Hello, world\n"
.equ hello_len, 13

# this sets the current section to .text (creating it in output file if not already present)
.text
# in the linker script 'kernel.ld', .text.boot is defined as an entry point to our kernel
boot:
  # TODO learn more details on this
  # RISC-V uses 32-bit wide instructions (generally) with various formats
  # one of which is U-type format
  # 31                             11         6          0
  # |    Imm[31:12]                |    rd    |  opcode  |
  # Here the lower 7 bits is used for opcode
  # the next 5 bits are used for destination register
  # and the last 20 bits are for the immediate value
  # For RV32, the address size (and also the word size) is 32 bits
  # meaning the whole 32-bit address (or constant) can't be specified
  # in a single instruction. Thus we need two instruction to build the address
  # of 'hello'.
  # AUIPC (add upper immediate to pc) is used to build pc-relative address and
  # it uses the U-type format described above. What is does it this:
  # - make a 32 bit offset value by filling lower 12 bits with zero
  #     and immediate in the upper 20 bits
  # - add this offset to the address of the AUIPC instruction (pc)
  # - store the result in the destination register
  # So how do we get the address of hello in a0 register?
  # we use %pcrel_hi to get the high 20 bits of relative address between pc and
  # the symbol 'hello' 
  auipc a0, %pcrel_hi(hello)
  # a0 now contains the high 20 bit pc relative address of the symbol 'hello'
  # we now need to add the lower 12 bits of the address of symbol 'hello'
  # to a0 to get the full address in a0
  # It doesn't work if I use %pcrel_lo instead of %lo here, even though the
  # docs says %pcrel_hi is paired with %pcrel_lo. I don't know why?
  # TODO so also look into that
  addi a0, a0, %lo(hello)
  # or we can use the pseudoinstruction 'la' to load the adderess of symbol
  # 'hello' into a0. this will be assembled into auipc and addi instruction
  # but with correct sequence based on whether the code is assembled as PIC
  # la a0, hello
  #
  # JAL (Jump And Link) instruction uses the J-type format
  # |[20]|    imm[10:1]      |[11]|      imm[19:12]     |    rd   |  opcode  |
  # J immediate encodes a signed offset in multiples of 2 bytes.
  # This offset is sign extended as added to the address of this jal
  # instruction to form the target address. the address of next instruction
  # (pc + 4) is stored in the destination register rd. 
  # so we are basically calling the sbi_printer function
  # with the address of hello world string we previously stored in register a0
  # also as a convention, ra register is used to store the return address
  # here the address of wfi instruction, so that when the sbi_printer returns
  # the pc jumps to wfi instruction below
  jal ra, sbi_printer
  # wfi is a privileged instruction that tells the execution environment that it
  # can stall this hart until an interrupt needs servicing
  # TODO what does OPENSBI do in case of wfi
  wfi

spin:
  # x0 is a special register in RISC-V as any reads from x0 will return all zeros
  # while any write to x0 will be ignored. so a jal instruction with destination
  # register x0 is an unconditional jump to that address. Here we jump to this
  # address running an infinite loop if the execution environment tries to wake
  # this hart up after the wfi instruction
  jal x0, spin

# the calling convention for ABIs is to use a0 and a1 to pass the first and second
# function argument as well as the return value. additionally registers a2, a3, a4
# a5, a6, a7 can be used to pass third, fourth, ... function arguments if necessary
# since we are defining and calling our own functions, we don't need to adhere to
# the convention, but it doesn't hurt to follow it anyway
sbi_printer:
  # save the address of hello passed to this function in a0 register to t1 register
  # as we will need to overwrite a0 to pass argument to another function later
  mv t1, a0
  # store the return address passed in ra in t3 register as that will also be
  # overwritten later 
  mv t3, ra
# we define a label named loop here and we will keep running this loop
# printing next character (starting from the first one at the address passed in a0)
# each iteration and incrementing t1 by 1 (byte)
loop:
  # RV32I being load-store architecture, load and store instructions are the only
  # instructions that can access memory. all other instructions operate on register
  # only (and immediates)
  # Load instructions uses I-type format
  # |   imm[11:0]   |  rs1  |  funct3  |   rd   |  opcode  |
  # effective address = rs1 + sign extended immediate value
  # rd = value at effective address (depends on the type of load instruction)
  # LW = loads a word from the effective address
  # LH = loads half-word and sign extends it
  # LHU = loads half-word and zero extends it
  # LB, LBU = similar to LH, LHU but for byte
  # Here we are loading the byte from address stored at t1 ( + 0) and
  # storing it at a0 after zero extending it
  lbu a0, 0(t1)
  # BEQ and all other branch instructions use B-type instruction format
  # |   imm[12|10:5]   |   rs2   |   rs1   |  funct3  |  imm[4:1 | 11] |  opcode  |
  # The 12-bit B-immediate encodes the signed offset in multiple of two bytes
  # BEQ, BNE = takes the branch is rs1 and rs2 are equal and not respectively
  # BLT, BLTU = takes the branch if rs1 is less than rs2 using signed and unsinged
  #               comparision
  # BGE, BGEU = takes the branch if rs1 is greater than or equal to rs2 using
  #               signed and unsigned comparision
  # Here we check if the character loaded into a0 is 0 or not (null terminated
  # string). If it is equal, we take the branch and jump to loop_end
  beq a0, x0, loop_end
  # if it is not equal, we call the sbi_printer function saving the return address
  # in register ra, we already have loaded the character we what to print in a0
  jal ra, sbi_putchar
  # we increment the value at t1 by 1 (byte) so that i points to the next character
  addi t1, t1, 1
  # and unconditionally jump back to loop label
  jal x0, loop
# when a0 equals 0 we jump here
loop_end:
  # we restore the return address passed to this function in register ra
  mv ra, t3
  # and return to that address
  ret

# we are using the opensbi, an implementation of RISC-V Supervisor Binary
#  Interface also called an Supervisor Execution Environment (SEE).
# The SBI allows supervisor-mode software to be portable across all RISC-V
# implementations by defining an abstraction for platform specific
# functionality. The functionality we are going to use here is 
# Console Putchar function of the Legacy Extention. It has an extension
# ID (EID) of 1 that we need to pass to register a7. This function accepts
# a single argument a character to print on the screen and according to convention
# this character should go into a0 register
sbi_putchar:
  # so we load the EID of 1 in register a7
  li a7, 1
  # and use ECALL instruction, which is used to make a service request to the
  # execution environment (OpenSBI in our case). As I described above, EID of 1
  # corresponds to Console Putchar which expects one argument the character to
  # print in register a0, which we pass as a parameter to this sbi_putchar
  # function from sbi_printer
  ecall
  ret


# Instead of using the legacy extension, we can use the Debug Console Extension
# with EID: 0x4442434E and its function Console Write with FID: 0
# This function has three parameters:
#   a0: number of bytes in the input memory
#   a1: lower XLEN bits of the physical base address of input memory
#   a2: upper XLEN bits of the same
# we defined this function so that the argument passed to Console Write
# function is passed to this function in the same registers by the caller
# of this function
sbi_printer_2:
  li a6, 0
  # if you are paying attention and also have keen eyes, you may have realized
  # that we are loading a 32 bits value into a7 and according to the instruction
  # format we've discussed(if not go read the part 0 blog) the maximum number
  # of bits we can use to make immediate value in any format is 20 bits
  # this li instruction is actually a pseudo instruction like the la instruction
  # we've seen above which is made up of lui + addi
  li a7, 0x4442434E
  ecall
  ret
