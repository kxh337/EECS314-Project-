    .data
# Command names
loadCmd:	.asciiz "LD\n"
discardCmd:	.asciiz "DC\n"
saveCmd:	.asciiz "SV\n"
removeCmd:	.asciiz "RM\n"
copyCmd:	.asciiz "CP\n"
insertCmd:	.asciiz "IN\n"
exitCmd:	.asciiz "EX\n"
# Words which can be printed
load:		.asciiz "Load"
discard:	.asciiz "Discard"
save:		.asciiz "Save"
remove:		.asciiz "Remove"
copy:		.asciiz "Copy"
insert:		.asciiz "Insert"
exit:		.asciiz "Exit"
complete:	.asciiz " complete!\n"
fin:		.space 16	# Space for input file name
fout:		.space 16	# Space for output file name
command: .space 4		# set aside a space for reading in commands
buffer: .space 32		# set aside a space for reading in file data
    .text
    
#Loop continuously, reading commands
NextCommand:
li $v0, 8
la $a0, command
li $a1, 4
syscall
la $t0, command
lb $t1, 0($t0)
sll $t1, $t1, 8
lb $t2, 1($t0)
or $t1, $t1, $t2
sll $t1, $t1, 8
lb $t2, 2($t0)
or $s0, $t1, $t2
# Determine which command was invoked
la $t0, loadCmd
jal AvailableCommand
beq $s1, $zero, LoadFile
la $t0, discardCmd
jal AvailableCommand
beq $s1, $zero, DiscardFile
la $t0, saveCmd
jal AvailableCommand
beq $s1, $zero, SaveFile
la $t0, removeCmd
jal AvailableCommand
beq $s1, $zero, Test
la $t0, copyCmd
jal AvailableCommand
beq $s1, $zero, Test
la $t0, insertCmd
jal AvailableCommand
beq $s1, $zero, Test
la $t0, exitCmd
jal AvailableCommand
beq $s1, $zero, Exit
j NextCommand

Test:
la $a0, complete
li $v0, 4
syscall
j NextCommand

AvailableCommand:
lb $t1, 0($t0)
sll $t1, $t1, 8
lb $t2, 1($t0)
or $t1, $t1, $t2
sll $t1, $t1, 8
lb $t2, 2($t0)
or $s1, $t1, $t2
sub $s1, $s1, $s0
jr $ra

PrintComplete:
la $a0, 0($t0)
li $v0, 4
syscall
la $a0, complete
li $v0, 4
syscall
jr $ra

RemoveNewLine:
la $t1, 0($t0)
CharacterLoop:
lb $t2, 0($t1)
addi $t1, $t1, 1
bne $t2, $zero, CharacterLoop
subi $t1, $t1, 2
sb $zero, 0($t1)
jr $ra
    
#li $t0, 1
#li $t1, 2
#add $t3, $t0, $t1
#la $t0, buffer

LoadFile:
# Read in name of file to use as input
li $v0, 8
la $a0, fin
li $a1, 16
syscall
la $t0, fin
jal RemoveNewLine

li $t0, 0x10010100
li $t3, 0x10400000
#sb $t3, ($t0)

# Open a file for reading
li   $v0, 13		# system call for open file
la   $a0, fin		# board file name
li   $a1, 0		# Open for reading
li   $a2, 0
syscall			# open a file (file descriptor returned in $v0)
move $s6, $v0		# save the file descriptor 

Read:
# Read from file
li   $v0, 14		# system call for read from file
move $a0, $s6		# file descriptor 
move $a1, $t0		# address of buffer to which to read
li   $a2, 32		# hardcoded buffer length
syscall			# read from file
lw   $t1, 0($t0)	# get value of the bytes just read
addi $t0, $t0, 0x20	# move to next memory address
sub $t4, $t3, $t0	# check whether memory out of bounds
bne  $t4, $zero, Read	# if not at the end of file, keep reading

# Close the file 
li   $v0, 16		# system call for close file
move $a0, $s6		# file descriptor to close
syscall			# close file
la $t0, load
jal PrintComplete
j NextCommand

SaveFile:
li $v0, 8
la $a0, fout
li $a1, 16
syscall
la $t0, fout
jal RemoveNewLine

###############################################################
# Open (for writing) a file that does not exist
li   $v0, 13		# system call for open file
la   $a0, fout		# output file name
li   $a1, 1		# Open for writing (flags are 0: read, 1: write)
li   $a2, 0		# mode is ignored
syscall			# open a file (file descriptor returned in $v0)
move $s6, $v0		# save the file descriptor 
###############################################################
# Write to file just opened
li $t0, 0x10010100
li $t3, 0x103fffe0
Write:
li   $v0, 15		# system call for write to file
move $a0, $s6		# file descriptor 
move $a1, $t0		# address of buffer from which to write
li   $a2, 32		# hardcoded buffer length
syscall			# write to file
lw   $t1, 0($t0)	# get value of the bytes just written
addi $t0, $t0, 0x20	# move to next memory address
sub $t4, $t3, $t0	# ensure end of data not reached
bne  $t4, $zero, Write	# if not all data written, keep writing
###############################################################
# Close the file 
li   $v0, 16		# system call for close file
move $a0, $s6		# file descriptor to close
syscall			# close file
la $t0, save
jal PrintComplete
j NextCommand
###############################################################

DiscardFile:
li $t0, 0x10010100
li $t1, 0x10400000
Discard:
sw $zero, 0($t0)
addi $t0, $t0, 4
sub $t2, $t1, $t0
bne $t2, $zero, Discard
la $t0, discard
jal PrintComplete
j NextCommand

Exit:
# Exit the program