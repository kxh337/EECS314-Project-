    .data
# Command names
loadCmd:	.asciiz "LD\n"
discardCmd:	.asciiz "DC\n"
saveCmd:	.asciiz "SV\n"
removeCmd:	.asciiz "RM\n"
copyCmd:	.asciiz "CP\n"
addCmd:		.asciiz "AD\n"
insertCmd:	.asciiz "IN\n"
overlayCmd:	.asciiz "OL\n"
volumeUpCmd:	.asciiz "V+\n"
volumeDownCmd:	.asciiz "V-\n"
speedUpCmd:	.asciiz "S+\n"
slowDownCmd:	.asciiz "S-\n"
exitCmd:	.asciiz "EX\n"
# Words which can be printed
load:		.asciiz "Load"
discard:	.asciiz "Discard"
save:		.asciiz "Save"
remove:		.asciiz "Remove"
copy:		.asciiz "Copy"
addName:	.asciiz "Add"
insert:		.asciiz "Insert"
overlay:	.asciiz "Overlay"
volumeUp:	.asciiz "VolumeUp"
volumeDown:	.asciiz "VolumeDown"
speedUp:	.asciiz "SpeedUp"
slowDown:	.asciiz "SlowDown"
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
la $t0, addCmd
jal AvailableCommand
beq $s1, $zero, AddClip
la $t0, insertCmd
jal AvailableCommand
beq $s1, $zero, InsertClip
la $t0, overlayCmd
jal AvailableCommand
beq $s1, $zero, OverlayClip
la $t0, volumeUpCmd
jal AvailableCommand
beq $s1, $zero, VolumeUpFile
la $t0, volumeDownCmd
jal AvailableCommand
beq $s1, $zero, VolumeDownFile
la $t0, speedUpCmd
jal AvailableCommand
beq $s1, $zero, SpeedUpFile
la $t0, slowDownCmd
jal AvailableCommand
beq $s1, $zero, SlowDownFile
la $t0, exitCmd
jal AvailableCommand
beq $s1, $zero, Exit
j NextCommand

Test:
la $a0, complete
li $v0, 4
syscall
j NextCommand

AvailableCommand:	# Compare the received command with one of the available commands to see which one it is
lb $t1, 0($t0)
sll $t1, $t1, 8
lb $t2, 1($t0)
or $t1, $t1, $t2
sll $t1, $t1, 8
lb $t2, 2($t0)
or $s1, $t1, $t2
sub $s1, $s1, $s0
jr $ra

PrintComplete:		# Print a message indicating that this command has finished running
la $a0, 0($t0)
li $v0, 4
syscall
la $a0, complete
li $v0, 4
syscall
jr $ra

RemoveNewLine:		# Remove newline character from an entered command
la $t1, 0($t0)
CharacterLoop:
lb $t2, 0($t1)
addi $t1, $t1, 1
bne $t2, $zero, CharacterLoop
subi $t1, $t1, 2
sb $zero, 0($t1)
jr $ra


LoadFile:		# Load the audio data to work with from a given file
# Read in name of file to use as input
li $v0, 8
la $a0, fin
li $a1, 16
syscall
la $t0, fin
jal RemoveNewLine

li $t0, 0x10010100
li $t3, 0x10200000

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
# Adjust audio file size to reflect limited memory space (file is truncated if too long)
li $t0, 0x10010100
li $t1, 0x10200000
sub $t1, $t1, $t0
lw $t2, 4($t0)
sub $a0, $t1, $t2
bgt $a0, $zero, PrintLoadResults
jal UpdateFileSizeValues
PrintLoadResults:
la $t0, load
jal PrintComplete
j NextCommand

SaveFile:		# Save the manipulated audio data to a specified file
# Read in the file name entered
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

DiscardFile:		# Discard the main audio file data being worked with (used if we want to load another file instead)
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

ClearData:		# Clear the data stored in the copy section of the memory
li $t0, 0x10200000
li $t1, 0x10400000
Clear:
sb $zero, 0($t0)
addi $t0, $t0, 1
sub $t2, $t1, $t0
bne $t2, $zero, Clear
jr $ra

CopyClip:		# Copy an audio clip from the main audio file section of memory to the copy section of memory
# Get memory address values corresponding to second values provided in the command
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

AddClip:		# Add the data in the copy section to the end of the audio file data (if there is room)
li $t0, 0x10010100
addi $t0, $t0, 4
lw $t1, 0($t0)     #file size
addi $t0, $t0, 4
add $t0, $t0, $t1  #address at the end of the file
li $t1, 0x10200000
bge $t0, $t1, PrintAddComplete
move $t2, $t0
move $t3, $t1
li $t5, 0x10400000
li $t6, 0
# Loop through all the copy data, copying it to the end of the audio file data
Add:
lb $t4, 0($t3)
sb $t4, 0($t2)
addi $t2, $t2, 1
addi $t3, $t3, 1
beq $t3, $t5, AddMaxMemory
addi $t6, $t6, 1
bne $t6, $s2, Add
move $a0, $s2
jal UpdateFileSizeValues
j PrintAddComplete
AddMaxMemory:
sub $a0, $t5, $t1
jal UpdateFileSizeValues
PrintAddComplete:
la $t0, addName
jal PrintComplete
j NextCommand

RemoveClip:		# Removes the specified section of audio data from the audio file data
# Read in the second values between which to remove audio data
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
# Write over each data byte in the indicated section
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

InsertClip:		# Insert the data in the copy section into the specified location in the audio file section of memory
li $v0, 5
syscall
move $a0, $v0
jal AddressFromSeconds
move $t0, $v0
li $t1, 0x10010100
addi $t4, $t1, 4
lw $t2, 0($t4)	     #get file size
addi $t4, $t4, 4
li $t2, 0x10200000
add $t1, $t2, $s2    #address of end  of copy data
add $t4, $t1, $s2    #address of end  of copy data  + copy data  
add $t3, $t0, $s2
move $t5 $t1
Shift:  		#makes space for the insertion
lb $t2, 0($t1)
sb $t2, 0($t4)
subi $t1, $t1, 1
subi $t4, $t4, 1
bne   $t3, $t4, Shift
add $t3, $t0, $s2	#insert point + copied data
move $t2, $t5		#Beginning of shifted copy data	
Insert:			#inserts the data in the space
lb $t4, 0($t2)
sb $zero, 0($t2)
sb $t4, 0($t0)
addi $t2, $t2, 1
addi $t0, $t0, 1
bne $t3, $t0, Insert
move $a0 $s2
jal UpdateFileSizeValues
PrintInsertComplete:
la $t0, insert
jal PrintComplete
j NextCommand

OverlayClip:		# Add one audio clip to another so that both play simultaneously
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
# Loop through the data in the copy section and add it to the appropriate data in the audio file section
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

SpeedUpFile:			# Increase the frequency at which the audio file is played
li $a3, 1
j SpeedChangeFile

SlowDownFile:			# Decrease the frequency at which the audio file is played
li $a3, -1
j SpeedChangeFile

SpeedChangeFile:		# Change the frequency at which the audio data is played
li $t0, 0x10010100
addi $t0, $t0, 22
lh $t5, 0($t0)
lw $t1, 2($t0)
lw $t2, 6($t0)
lh $t3, 12($t0)
li $t4, 1
bgt $a3, $zero, SpeedUp
SlowDown:
subi $t1, $t1, 5000
move $t2, $t1
# Multiply by bits per sample
mult $t2, $t3
mflo $t2
# Multiply by number of channels
mult $t2, $t5
mflo $t2
# Divide by 8
sra $t2, $t2, 3
j SaveSpeedChange
SpeedUp:
addi $t1, $t1, 5000
move $t2, $t1
# Multiply by bits per sample
mult $t2, $t3
mflo $t2
# Multiply by number of channels
mult $t2, $t5
mflo $t2
# Divide by 8
sra $t2, $t2, 3
SaveSpeedChange:
sw $t1, 2($t0)
sw $t2, 6($t0)
bgt $a3, $zero, SpeedUpPrint
SlowDownPrint:
la $t0, slowDown
jal PrintComplete
j NextCommand
SpeedUpPrint:
la $t0, speedUp
jal PrintComplete
j NextCommand


VolumeUpFile:		# Increase the volume of the WAV file
li $a0, 1
j VolumeChangeFile

VolumeDownFile:		# Decrease the volume of the WAV file
li $a0, -1
j VolumeChangeFile

VolumeChangeFile:	# Adjust the volume of the file up or down, depending on the command given
li $t0, 0x10010100
addi $t0, $t0, 16	# Go to format chunk size field
lw $t1, 0($t0)		# Get format chunk size
add $t0, $t0, $t1	
addi $t0, $t0, 8	# Go to data chunk size
lw $t1, 0($t0)
addi $t0, $t0, 4	# Go to start of data
li $t2, 0
li $t3, 0x10010100
addi $t3, $t3, 34
lh $t4, 0($t3)
li $t5, 16
bne $t4, $t5, EndVolumeChange
VolumeChange:
lh $t3, 0($t0)
bgt $a0, $zero, VolumeUp
sra $t3, $t3, 1		# Lower volume by factor of 2
j VolumeChanged
VolumeUp:
sll $t3, $t3, 1		# Raise volume by factor of 2
VolumeChanged:
sh $t3, 0($t0)
addi $t0, $t0, 2
addi $t2, $t2, 2
blt $t2, $t1, VolumeChange
EndVolumeChange:
# Print the appropriate message - "volume up complete" or "volume down complete"
bgt $a0, $zero, VolUpPrint
la $t0, volumeDown
jal PrintComplete
j NextCommand
VolUpPrint:
la $t0, volumeUp
jal PrintComplete
j NextCommand

AddressFromSeconds:		# Get the memory address containing the audio data corresponding to an input seconds value
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



UpdateFileSizeValues:		# Adjust file size to account for inserts or deletions of data
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
