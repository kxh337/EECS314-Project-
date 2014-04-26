    .data
# Command names
loadCmd:	.asciiz "LD\n"
discardCmd:	.asciiz "DC\n"
saveCmd:	.asciiz "SV\n"
removeCmd:	.asciiz "RM\n"
copyCmd:	.asciiz "CP\n"
insertCmd:	.asciiz "IN\n"
overlayCmd:	.asciiz "OL\n"
exitCmd:	.asciiz "EX\n"
# Words which can be printed
load:		.asciiz "Load"
discard:	.asciiz "Discard"
save:		.asciiz "Save"
remove:		.asciiz "Remove"
copy:		.asciiz "Copy"
insert:		.asciiz "Insert"
overlay:	.asciiz "Overlay"
exit:		.asciiz "Exit"
complete:	.asciiz " complete!\n"
fin:		.space 16	# Space for input file name
fout:		.space 16	# Space for output file name
command: 	.space 4	# set aside a space for reading in commands
buffer: 	.space 32	# set aside a space for reading in file data
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
beq $s1, $zero, RemoveClip
la $t0, copyCmd
jal AvailableCommand
beq $s1, $zero, CopyClip
la $t0, insertCmd
jal AvailableCommand
beq $s1, $zero, InsertClip
la $t0, overlayCmd
jal AvailableCommand
beq $s1, $zero, OverlayClip
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
li $t3, 0x10200000
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
li $t0, 0x10010100
li $t1, 0x10200000
sub $t1, $t1, $t0
lw $t2, 4($t0)
sub $a0, $t1, $t2
jal UpdateFileSizeValues
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
li $t3, 0x101fffe0
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
li $t1, 0x10200000
Discard:
sw $zero, 0($t0)
addi $t0, $t0, 4
sub $t2, $t1, $t0
bne $t2, $zero, Discard
la $t0, discard
jal PrintComplete
j NextCommand

ClearData:
li $t0, 0x10200000
li $t1, 0x10400000
Clear:
sb $zero, 0($t0)
addi $t0, $t0, 1
sub $t2, $t1, $t0
bne $t2, $zero, Clear
jr $ra

CopyClip:
# COMPLETE? - could modify
jal ClearData
li $v0, 5
syscall
move $a0, $v0
jal AddressFromSeconds
move $t0, $v0
li $v0, 5
syscall
move $a0, $v0
jal AddressFromSeconds
move $t1, $v0
li $t2, 0x10200000
li $t3, 0x10400000
sub $t4, $t1, $t0
sub $t5, $t3, $t2
bgt $t4, $t5, MaxMemory		# Check if section to copy greater than maximum memory available for it
move $s2, $t4			# Load length of the copied section
j Copy
MaxMemory:
move $s2, $t5			# Load length of the copied section
Copy:
lb $t4, 0($t0)
sb $t4, 0($t2)
addi $t0, $t0, 1
addi $t2, $t2, 1
beq $t2, $t3, EndCopy
bne $t0, $t1, Copy
EndCopy:
la $t0, copy
jal PrintComplete
j NextCommand

RemoveClip:
# COMPLETE
li $v0, 5
syscall
move $a0, $v0
jal AddressFromSeconds
move $t0, $v0
li $v0, 5
syscall
move $a0, $v0
jal AddressFromSeconds
move $t1, $v0
move $t2, $t0
move $t3, $t1
li $t4, 0x10200000
Remove:
lb $t5, 0($t3)
sb $t5, 0($t2)
addi $t2, $t2, 1
addi $t3, $t3, 1
bne $t2, $t4, Remove
sub $a0, $t0, $t1
jal UpdateFileSizeValues
la $t0, remove
jal PrintComplete
j NextCommand

InsertClip:
# INCOMPLETE
li $v0, 5
syscall
move $t0, $v0
la $t0, insert
jal PrintComplete
j NextCommand

OverlayClip:
# COMPLETE? - Could add support for different data sizes (other than 16 bits)
li $v0, 5
syscall
move $a0, $v0
jal AddressFromSeconds
move $t0, $v0
li $t1, 0x10200000
move $t2, $zero
li $t3, 0x10010100
addi $t3, $t3, 34
lh $t4, 0($t3)
li $t5, 16
bne $t4, $t5, EndOverlay
li $t6, 0x10400000
Overlay:
lh $t3, 0($t0)
lh $t4, 0($t1)
add $t4, $t3, $t4
sh $t4, 0($t0)
addi $t0, $t0, 2
addi $t1, $t1, 2
beq $t1, $t6, EndOverlay
addi $t2, $t2, 2
blt $t2, $s2, Overlay
EndOverlay:
la $t0, overlay
jal PrintComplete
j NextCommand

AddressFromSeconds:
addi $sp, $sp, -20
sw $ra, 16($sp)
sw $t3, 12($sp)
sw $t2, 8($sp)
sw $t1, 4($sp)
sw $t0, 0($sp)
li $t0, 0x10010100
addi $t0, $t0, 16	# Go to format chunk size field
lw $t1, 0($t0)		# Get format chunk size
lw $t2, 12($t0)		# Get bytes per second value
add $t0, $t0, $t1
addi $t0, $t0, 12	# Go to start of sound data
add $t3, $zero, $zero
AddressSearch:
bge $t3, $a0, AddressFound
addi $t3, $t3, 1
add $t0, $t0, $t2
j AddressSearch
AddressFound:
move $v0, $t0
lw $t0, 0($sp)
lw $t1, 4($sp)
lw $t2, 8($sp)
lw $t3, 12($sp)
lw $ra, 16($sp)
addi $sp, $sp, 20
jr $ra

UpdateFileSizeValues:
addi $sp, $sp, -20
sw $ra, 16($sp)
sw $t7, 12($sp)
sw $t6, 8($sp)
sw $t5, 4($sp)
sw $t4, 0($sp)
li $t4, 0x10010100
addi $t4, $t4, 4	# Access file size field
lw $t5, 0($t4)
add $t5, $t5, $a0
addi $t6, $t4, 12	# Access format chunk size field
lw $t7, 0($t6)
add $t6, $t6, $t7
addi $t6, $t6, 8	# Access data chunk size field
lw $t7, 0($t6)
add $t7, $t7, $a0
blt $t7, $zero, EndUpdate	# Can't make data size less than 0
sw $t5, 0($t4)
sw $t7, 0($t6)
EndUpdate:
lw $t4, 0($sp)
lw $t5, 4($sp)
lw $t6, 8($sp)
lw $t7, 12($sp)
lw $ra, 16($sp)
addi $sp, $sp, 12
jr $ra

Exit:
# Exit the program
