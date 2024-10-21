.data
gridsize:   .byte 8, 8
character:  .byte -1,-1
box:        .word -1
target:     .word -1
playerScores: .word -1 
boardCopy: .word -1 
seed: .word -1 

targetString: .string "*"
boxString: .string "#"
playerString: .string "X"
emptyString: .string " "
wallString: .string "O"
newLine: .string "\n"
invalidInput: .string "\nInvalid input. "
invalidMove: .string "\nInvalid move. "
lineString: .string "\n\n -------------- \n"
scoreBoard: .string "  SCOREBOARD:  \n"
numPlayersText: .string "\nHow many players should compete?\n"
playerWonText_1: .string "\nPLAYER " 
playerWonText_2: .string " WON IN "
playerWonText_3: .string " MOVES" 
gameOverString: .string "Press 'r' to Play Again"
introString: .string "\n\n -------------- \n 'wasd': Moves player around \n 'r': Resets board \n\n -------------- "
.align 4 

.text
.globl _start

_start:
	li sp, 0x80000000
	
	# generate random seed
	la t0, seed 
	li a7, 30
    ecall             # time syscall
	sw a0, 0(t0)
	
	la a7, 4 
	la a0, introString
	ecall
	
	NUM_PLAYERS:
		li a7, 4 
		la a0, numPlayersText
		ecall 
		
		#take input
		li a7, 5
		ecall
		mv s11, a0
		
		#make input 1 if it was invalid or 0 
		li t0, 1 
		bge s11, t0, DONE_NUM_PLAYERS
		li s11, 1 
	
	DONE_NUM_PLAYERS:
		li t0, 4 
		mul t1, s11, t0 
		
		#move stack down and store location in playerScores
		sub sp, sp, t1
		la t1, playerScores
		sw sp, 0(t1)
	
	#t0 = number of boxes * 2: one for x, one for y 
	jal ra, numBoxes
	mv t0, a0
	slli t0, t0, 1
	
	#move stackpointer by t0
	#store box stackpointer location in box
	sub sp, sp, t0 
	la t1, box
	sw sp, 0(t1)
	
	#store target stackpointer location in target
	sub sp, sp, t0 
	la t1, target
	sw sp, 0(t1)
	
	#reset all used stack addresses to -1 
	mv t1, sp 
	li t2, 0x80000000
	li t3, -1
	RESET_STACK:
		sb t3, 0(t1)
		addi t1, t1, 1
		bne t2, t1, RESET_STACK
	
	#s5 = number of boxes 
	srli s5, t0, 1
	li s4, 0
	TARGET_GEN:
		#s2 = random(0 to gridsize)
		la t0, gridsize 
		lb a0, 0(t0)
		jal ra, notrand
		mv s2, a0

		#s3 = random(0 to gridsize)
		la t0, gridsize 
		lb a0, 1(t0)
		jal ra, notrand
		mv s3, a0
		
		#reset if there is an overlap
		mv a0, s2 
		mv a1, s3
		jal ra, noDups
		beq a0, x0, TARGET_GEN
		
		#setup target address
		la t1, target
		lw t1, 0(t1)
		slli s6, s4, 1
		add t1, t1, s6 #increment target address
		
		#store target coordinates
		sb s2, 0(t1)
		sb s3, 1(t1)
		
		addi s4, s4, 1
		bne s4, s5, TARGET_GEN
	
	li s4, 0
	BOX_GEN:
		#s2 = random(0 to gridsize)
		la t0, gridsize 
		lb a0, 0(t0)
		jal ra, notrand
		mv s2, a0

		#s3 = random(0 to gridsize)
		la t0, gridsize 
		lb a0, 1(t0)
		jal ra, notrand
		mv s3, a0
		
		#reset if there is an overlap with target
		mv a0, s2 
		mv a1, s3
		jal ra, noDups
		beq a0, x0, BOX_GEN
		
		#reset if the box is in a corner or a bad side
		mv a0, s2 
		mv a1, s3
		jal ra, boxValidity
		beq a0, x0, BOX_GEN
		
		#setup box address
		la t1, box
		lw t1, 0(t1)
		slli s6, s4, 1
		add t1, t1, s6 #increment box address
		
		#store box coordinates
		sb s2, 0(t1)
		sb s3, 1(t1)
		
		addi s4, s4, 1
		bne s4, s5, BOX_GEN
	
	CHARACTER_GEN:
		#s2 = random(0 to gridsize)
		la t0, gridsize 
		lb a0, 0(t0)
		jal ra, notrand
		mv s2, a0

		#s3 = random(0 to gridsize)
		la t0, gridsize 
		lb a0, 1(t0)
		jal ra, notrand
		mv s3, a0
		
		#reset if there is an overlap
		mv a0, s2 
		mv a1, s3
		jal ra, noDups
		beq a0, x0, CHARACTER_GEN
		
		#store character
		la t1, character
		sb s2, 0(t1)
		sb s3, 1(t1)
		
	PLAYER_SETUP:
		#move stackpointer down with enough space for target and boxes duplication
		jal ra, numBoxes 
		slli t0, a0, 2
		sub sp, sp, t0
		
		la t2, boardCopy
		sw sp, 0(t2)
		lw t2, 0(t2)
		
		la t3, target
		lw t3, 0(t3)
		li t1, 0
		DUPLICATE_BOARD:
			#store a copy of the board target/boxes in boardCopy
			lb t4, 0(t3)
			sb t4, 0(t2)
			
			addi t3, t3, 1 
			addi t2, t2, 1 
			addi t1, t1, 1
			bne t1, t0, DUPLICATE_BOARD
			
		la t0, character
		lb s7, 0(t0)
		lb s8, 1(t0)
		
	li s9, -1
	li s10, 0  
	GAMELOOP:		
		addi s9, s9, 1 
		jal ra, constructString
		
		MOVELOOP:
			#take input
			li a7, 12
			ecall
			mv t0, a0

			# r restarts game, wasd jump to moveCharacter
			li t1, 114 # r 
			bne t0, t1, SKIP_RESTART
			
			jal ra, resetBoard
			j GAMELOOP
			SKIP_RESTART:

			li a0, 119 # w
			beq t0, a0, moveCharacter
			li a0, 97 # a
			beq t0, a0, moveCharacter
			li a0, 115 # s
			beq t0, a0, moveCharacter
			li a0, 100 # d
			beq t0, a0, moveCharacter

			# jump back to moveloop without reprinting board
			# if the inputted value was invalid
			la a0, invalidInput
			li a7, 4 
			ecall
			j MOVELOOP
		
		DONE_MOVING: 
			# jump back to moveloop without reprinting board
			# if the movement was invalid
			beq a0, x0, MOVELOOP
			
			#exit if all boxes are on their targets
			jal ra, checkGameDone
			bne a0, x0, PLAYER_FINISHED
			
			j GAMELOOP
	
PLAYER_FINISHED:
	la t0, playerScores 
	lw t1, 0(t0)
	
	#store player score on stack, increment playerScores address
	sw s9, 0(t1)
	addi t1, t1, 4
	sw t1, 0(t0)
	
	addi s10, s10, 1 
	beq s10, s11, exit
	
	li s9, -1 
	jal ra, resetBoard
	j GAMELOOP
		
		
exit:
	li a7, 4
	la a0, lineString
	ecall
	li a7, 4
	la a0, scoreBoard 
	ecall

	la t0, playerScores 
	li t3, 0 
	SORT_LOOP:
	
		lw t1, 0(t0) # player score address
		addi t1, t1, -4
		li t4, 0 # counter
		li t6, 2147483647 # smallest score
		SEARCH_LOOP: 
			lw t5, 0(t1)
			
			# so that the first player wins in case of a tie 
			addi a0, t5, -1
			bge a0, t6, DONE_SEARCH
			
			mv t6, t5 
			mv a1, t1 
			sub s8, s11, t4
			
			DONE_SEARCH: 
			addi t1, t1, -4
			addi t4, t4, 1 
			bne t4, s11, SEARCH_LOOP
			
		li a7, 4
		la a0, playerWonText_1  
		ecall
		li a7, 1 
		mv a0, s8
		ecall  
		li a7, 4 
		la a0, playerWonText_2 
		ecall 
		li a7, 1 
		mv a0, t6 
		ecall 
		li a7, 4 
		la a0, playerWonText_3 
		ecall 
		
		li t5, 2147483647
		sw t5, 0(a1)
		
		addi t3, t3, 1 
		bne t3, s11, SORT_LOOP
	
	
	li a7, 4
	la a0, lineString
	ecall
	
	li a7, 4
	la a0, gameOverString
	ecall 
	#take input
	li a7, 12
	ecall
	mv t0, a0

	# r restarts game
	li t1, 114 # r 
	beq t0, t1, _start
	
    li a7, 10
    ecall
    
    
# --- HELPER FUNCTIONS ---
     
# Arguments: None 
# Returns: None 
# Resets the board back to the one originally created
resetBoard:
	mv t2, ra 
	jal ra, numBoxes 
	mv ra, t2 
	slli t0, a0, 2
		
	la t2, boardCopy
	lw t2, 0(t2)
	la t3, target
	lw t3, 0(t3)
	
	li t1, 0
	RESET_LOOP:
		# restore boardCopy inside of the actual board 
		lb t4, 0(t2)
		sb t4, 0(t3)

		addi t3, t3, 1 
		addi t2, t2, 1 
		addi t1, t1, 1
		bne t1, t0, RESET_LOOP
		
	la t0, character  
	sb s7, 0(t0)
	sb s8, 1(t0)
	
	ret 
	 
# Arguments: an integer MAX in a0
# Return: A number from 0 (inclusive) to MAX (exclusive)

# Generates a random number using a Linear Congruential Generator
# Thomson, W. E. (1958). "A Modified Congruence Method of Generating 
#		Pseudo-random Numbers". The Computer Journal.

notrand:
	la t0, seed 
	lw t0, 0(t0)
	
	li a7, 1103515245 # a7 = a 
	mul t0, t0, a7 # t0 = seed * a 
	li a7, 12345 # a7 = c
	add t0, t0, a7 # t0 = (seed * a) + c 
	li a7, 2147483648 # a7 = m = 2^31 
	remu t0, t0, a7 # t0 = (seed * a + c) mod m 
	
	#update seed
	la a7, seed 
	sw t0, 0(a7)
	
	srli t0, t0, 10
	remu a0, t0, a0 # set range to 0 - MAX
    ret

# Arguments: None 
# Return: The number of boxes for this board based on gridsize
numBoxes:
	# numBoxes = gridsize // t0
	li t0, 3
	la t1, gridsize
	lb a0, 1(t1)
	lb t1, 0(t1)
	add t1, t1, a0 
	li a0, 2 
	div t1, t1, a0 
	div t0, t1, t0
	
	# ensures numBoxes >= 1  
	li t1, 1 
	bge t0, t1, GREATER_THAN_ONE
	li t0, 1
	
	GREATER_THAN_ONE:
	mv a0, t0 
	ret

# Arguments: a0: The x coordinate to check
#			 a1: The y coordinate to check 
# Return: 1 if a duplicate coordinate was found, 0 otherwise
noDups:
	#get the number of boxes, moving registers around to stop clobber
	mv a5, a0
	mv a6, a1 
	mv a7, ra
	
	jal ra, numBoxes
	mv t0, a0
	
	mv ra, a7
	mv a0, a5
	mv a1, a6
	
	li t1, 0 
	la t2, target
	lw t2, 0(t2)
	#check if any targets are ontop of the provided coordinate
	TARGET_CHECK:
		lb t3, 0(t2) # x
		lb t4, 1(t2) # y 
		
		bne t3, a0, DONE_TARGET_CHECK
		beq t4, a1, FOUND_DUPLICATE
		
		DONE_TARGET_CHECK:
			addi t2, t2, 2 
			addi t1, t1, 1
			bne t1, t0, TARGET_CHECK
			
	li t1, 0 
	la t2, box
	lw t2, 0(t2)
	#check if any boxes are ontop of the provided coordinate
	DUP_BOX_CHECK:
		lb t3, 0(t2) # x
		lb t4, 1(t2) # y 
		
		bne t3, a0, DONE_DUP_BOX_CHECK
		beq t4, a1, FOUND_DUPLICATE
		
		DONE_DUP_BOX_CHECK:
			addi t2, t2, 2 
			addi t1, t1, 1
			bne t1, t0, DUP_BOX_CHECK
		
	DONE:
		li a0, 1
		ret 
		
	FOUND_DUPLICATE:
		li a0, 0 
		ret

# Arguments: a0: the box's X coordinate
#			 a1: the box's Y coordinate
# Returns: 0 if the box is in a bad position
#		   1 if the box is in a solvable position
boxValidity:
	mv t0, a0 # x
	mv t1, a1 # y
	
	la t2, gridsize
	lb t3, 1(t2) # grid y
	addi t3, t3, -1
	lb t2, 0(t2) # grid x
	addi t2, t2, -1 
	
	#return 0 if the box is in any of the corners
	li a0, 0
	CHECK_CORNERS:
		TOP_LEFT_CHECK:
			bne t0, x0, TOP_RIGHT_CHECK 
			bne t1, x0, BOT_LEFT_CHECK
			ret

		BOT_LEFT_CHECK:
			bne t1, t3, CHECK_SIDES
			ret

		TOP_RIGHT_CHECK:
			bne t0, t2, CHECK_SIDES
			bne t1, x0, BOT_RIGHT_CHECK
			ret

		BOT_RIGHT_CHECK:
			bne t1, t3, CHECK_SIDES
			ret
	
	#return 0 if the box is on a side that doesnt contain the target
	#or if there are more than 1 boxes directly beside each other on a side
	CHECK_SIDES:
		#get number of boxes, move registers around to avoid clobber
		mv a5, t0
		mv a6, t1
		mv a7, ra 
		
		jal ra, numBoxes
		mv a1, a0
		
		mv t0, a5
		mv t1, a6
		mv ra, a7
		
		li t4, 1 # num of boxes on this side
		li a5, 0 # num of targets on this side
		li a0, 0
		LEFT_SIDE_CHECK:
			bne t0, x0, RIGHT_SIDE_CHECK 

			la a4, box
			lw a4, 0(a4)
			li t5, 0
			LEFT_SIDE_BOX_CHECK:
				lb t6, 0(a4)
				bne t0, t6, DONE_LEFT_SIDE_BOX_CHECK
				
				lb t6, 1(a4)
				addi t6, t6, 1 
				beq t6, t1, FAIL_BOX_CHECK
				addi t6, t6, -2 
				beq t6, t1, FAIL_BOX_CHECK
				
				addi t4, t4, 1
			
				DONE_LEFT_SIDE_BOX_CHECK:
				addi a4, a4, 2 
				addi t5, t5, 1
				bne t5, a1, LEFT_SIDE_BOX_CHECK
				
			la a4, target
			lw a4, 0(a4)
			li t5, 0
			LEFT_SIDE_TARGET_CHECK:
				lb t6, 0(a4)
				bne t0, t6, DONE_LEFT_SIDE_TARGET_CHECK
				
				lb t6, 1(a4)
				beq t6, x0, DONE_LEFT_SIDE_TARGET_CHECK
				beq t6, t3, DONE_LEFT_SIDE_TARGET_CHECK
				
				addi a5, a5, 1 
			
				DONE_LEFT_SIDE_TARGET_CHECK:
				addi a4, a4, 2 
				addi t5, t5, 1
				bne t5, a1, LEFT_SIDE_TARGET_CHECK
			
			bge a5, t4, DONE_BOX_CHECK
			ret
		
		RIGHT_SIDE_CHECK:
			bne t0, t2, TOP_SIDE_CHECK
			
			la a4, box
			lw a4, 0(a4)
			li t5, 0
			RIGHT_SIDE_BOX_CHECK:
				lb t6, 0(a4)
				bne t0, t6, DONE_RIGHT_SIDE_BOX_CHECK
				
				lb t6, 1(a4)
				addi t6, t6, 1 
				beq t6, t1, FAIL_BOX_CHECK
				addi t6, t6, -2 
				beq t6, t1, FAIL_BOX_CHECK
				
				addi t4, t4, 1
			
				DONE_RIGHT_SIDE_BOX_CHECK:
				addi a4, a4, 2 
				addi t5, t5, 1
				bne t5, a1, RIGHT_SIDE_BOX_CHECK
				
			la a4, target
			lw a4, 0(a4)
			li t5, 0
			RIGHT_SIDE_TARGET_CHECK:
				lb t6, 0(a4)
				bne t0, t6, DONE_RIGHT_SIDE_TARGET_CHECK
				
				lb t6, 1(a4)
				beq t6, x0, DONE_RIGHT_SIDE_TARGET_CHECK
				beq t6, t3, DONE_RIGHT_SIDE_TARGET_CHECK
				
				addi a5, a5, 1 
			
				DONE_RIGHT_SIDE_TARGET_CHECK:
				addi a4, a4, 2 
				addi t5, t5, 1
				bne t5, a1, RIGHT_SIDE_TARGET_CHECK
			
			bge a5, t4, DONE_BOX_CHECK
			ret
		
		TOP_SIDE_CHECK:
			bne t1, x0, BOT_SIDE_CHECK
			
			la a4, box
			lw a4, 0(a4)
			li t5, 0
			TOP_SIDE_BOX_CHECK:
				lb t6, 1(a4)
				bne t1, t6, DONE_TOP_SIDE_BOX_CHECK
				
				lb t6, 0(a4)
				addi t6, t6, 1 
				beq t6, t0, FAIL_BOX_CHECK
				addi t6, t6, -2 
				beq t6, t0, FAIL_BOX_CHECK
				
				addi t4, t4, 1
			
				DONE_TOP_SIDE_BOX_CHECK:
				addi a4, a4, 2 
				addi t5, t5, 1
				bne t5, a1, TOP_SIDE_BOX_CHECK
				
			la a4, target
			lw a4, 0(a4)
			li t5, 0
			TOP_SIDE_TARGET_CHECK:
				lb t6, 1(a4)
				bne t1, t6, DONE_TOP_SIDE_TARGET_CHECK
				
				lb t6, 0(a4)
				beq t6, x0, DONE_TOP_SIDE_TARGET_CHECK
				beq t6, t2, DONE_TOP_SIDE_TARGET_CHECK
				
				addi a5, a5, 1 
			
				DONE_TOP_SIDE_TARGET_CHECK:
				addi a4, a4, 2 
				addi t5, t5, 1
				bne t5, a1, TOP_SIDE_TARGET_CHECK
			
			bge a5, t4, DONE_BOX_CHECK
			ret
		
		BOT_SIDE_CHECK:
			bne t1, t3, DONE_BOX_CHECK
			
			la a4, box
			lw a4, 0(a4)
			li t5, 0
			BOT_SIDE_BOX_CHECK:
				lb t6, 1(a4)
				bne t1, t6, DONE_BOT_SIDE_BOX_CHECK
				
				lb t6, 0(a4)
				addi t6, t6, 1 
				beq t6, t1, FAIL_BOX_CHECK
				addi t6, t6, -2 
				beq t6, t1, FAIL_BOX_CHECK
				
				addi t4, t4, 1
			
				DONE_BOT_SIDE_BOX_CHECK:
				addi a4, a4, 2 
				addi t5, t5, 1
				bne t5, a1, TOP_SIDE_BOX_CHECK
				
			la a4, target
			lw a4, 0(a4)
			li t5, 0
			BOT_SIDE_TARGET_CHECK:
				lb t6, 1(a4)
				bne t1, t6, DONE_BOT_SIDE_TARGET_CHECK
				
				lb t6, 0(a4)
				beq t6, x0, DONE_BOT_SIDE_TARGET_CHECK
				beq t6, t2, DONE_BOT_SIDE_TARGET_CHECK
				
				addi a5, a5, 1 
			
				DONE_BOT_SIDE_TARGET_CHECK:
				addi a4, a4, 2 
				addi t5, t5, 1
				bne t5, a1, BOT_SIDE_TARGET_CHECK
			
			bge a5, t4, DONE_BOX_CHECK
			ret
		
		
	DONE_BOX_CHECK:
		li a0, 1
		ret
		
	FAIL_BOX_CHECK:
		li a0, 0
		ret
	
# Arguments: a0: x coordinate to check
#			 a1: y coordinate to check 
# Returns: 1 if a box was found in x, y
# 		   0 if no box was found in x, y
boxAtPoint:
	mv a3, ra 
	mv a2, a0 
	jal ra, numBoxes
	mv ra, a3
	li a3, 0 
	
	la a4, box
	lw a4, 0(a4)
	#loop through all the boxes, return 1 if any are on the provided coord
	CHECK_LOOP:
		lb a5, 0(a4)
		lb a6, 1(a4)
		
		bne a2, a5, DONE_CHECK
		bne a1, a6, DONE_CHECK
		
		li a0, 1
		ret
	
		DONE_CHECK:
		addi a4, a4, 2 
		addi a3, a3, 1 
		bne a3, a0, CHECK_LOOP
		
	li a0, 0
	ret

# Arguments: None 
# Returns: None 
# Prints the string to be portrayed
constructString:
	la t1, gridsize 
	lb t3, 0(t1) # x
	addi t3, t3, 1
	lb t4, 1(t1) # y
	addi t4, t4, 1

	la a0, newLine 
	li a7, 4 
	ecall
	
	mv a7, ra
	jal ra, numBoxes
	mv ra, a7
	mv a6, a0
		
	li t2, -1 # y counter
	WHILE_COLUMN:	
	
		li t1, -1 # x counter
		WHILE_ROW:
			
			#make a wall at the top and bottom rows
			li a2, -1
			beq t2, a2, CONSTRUCT_WALL
			addi a2, t4, -1
			beq t2, a2, CONSTRUCT_WALL
			
			#make a wall at the left and right columns
			li a2, -1
			beq t1, a2, CONSTRUCT_WALL
			addi a2, t3, -1 
			beq t1, a2, CONSTRUCT_WALL
			
			CONSTRUCT_PLAYER:
				#load character coord
				la t5, character
				lb t6, 1(t5)
				lb t5, 0(t5)
			
				#move to construct empty if current coord != player coord
				bne t5, t1, CONSTRUCT_BOX
				bne t6, t2, CONSTRUCT_BOX
				
				#print player string
				la a0, playerString 
				li a7, 4 
				ecall
				
				j DONE_CONSTRUCT

			CONSTRUCT_BOX:
				#load box coords
				la a3, box
				lw a3, 0(a3)
			
				li a1, 0
				#check every box to see if any fall on the current coord
				CONSTRUCT_BOX_LOOP:
					lb t5, 0(a3)
					lb t6, 1(a3)
					
					bne t5, t1, NOT_BOX_COORD
					bne t6, t2, NOT_BOX_COORD
					
					la a0, boxString 
					li a7, 4 
					ecall
				
					j DONE_CONSTRUCT
					
					NOT_BOX_COORD:
					addi a3, a3, 2
					addi a1, a1, 1
					bne a1, a6, CONSTRUCT_BOX_LOOP

			CONSTRUCT_TARGET:
				#load target coords
				la a3, target
				lw a3, 0(a3)
			
				li a1, 0
				#check every target to see if any fall on the current coord
				CONSTRUCT_TARGET_LOOP:
					lb t5, 0(a3)
					lb t6, 1(a3)
					
					bne t5, t1, NOT_TARGET_COORD
					bne t6, t2, NOT_TARGET_COORD
					
					la a0, targetString 
					li a7, 4 
					ecall
				
					j DONE_CONSTRUCT
					
					NOT_TARGET_COORD:
					addi a3, a3, 2
					addi a1, a1, 1
					bne a1, a6, CONSTRUCT_TARGET_LOOP
					
			CONSTRUCT_EMPTY:
				#print empty string
				la a0, emptyString 
				li a7, 4 
				ecall
				
				j DONE_CONSTRUCT
				
			CONSTRUCT_WALL:
				#print wall string
				la a0, wallString 
				li a7, 4 
				ecall
				
			DONE_CONSTRUCT:
				addi t1, t1, 1
				bne t1, t3, WHILE_ROW
		
		#print newline after row is complete
		la a0, newLine 
		li a7, 4 
		ecall
		
		addi t2, t2, 1 
		bne t2, t4, WHILE_COLUMN
			
	ret
	
# Arguments: a0; The user-inputted key
# Output: 1 for a successfull move, 0 for an invalid move
# 		  if the movement is valid, Moves the player coordinate 
#		  and pushes boxes accordingly. Otherwise, prints an invalid
#		  move string.
moveCharacter: 	
	mv t3, ra
	mv t2, a0
	jal ra, numBoxes
	mv t5, a0
	mv ra, t3
	
	la t1, character
	lb t0, 0(t1) # x
	lb t1, 1(t1) # y 
	
	# move to the side that the user-inputted key is trying to move to 
	# for that side, return error if player is moving into a wall
	# for that side, check if a box is ahead of the player 
	# 		and return an error if there is a box ahead of that box 
	# 		or  return an error if there is a wall ahead of that box 
	# otherwise, move the player and box accordingly 
	UP_MOVE:
		li t3, 119
		bne t2, t3, LEFT_MOVE

		beq t1, x0, ERROR_MOVE
		
		la t6, box
		lw t6, 0(t6)
		li t2, 0 
		UP_MOVE_LOOP:
			lb t3, 0(t6) # box x
			lb t4, 1(t6) 
			addi t4, t4, 1 # box y

			bne t3, t0, DONE_UP_MOVE
			bne t4, t1, DONE_UP_MOVE

			addi t4, t4, -1
			beq t4, x0, ERROR_MOVE
			
			mv a0, t3 
			addi a1, t4, -1 
			mv a7, ra
			jal ra, boxAtPoint
			mv ra, a7
			li a7, 1 
			beq a0, a7, ERROR_MOVE
			
			la t1, character
			lb t0, 0(t1) # x
			lb t1, 1(t1) # y 
			
			addi t4, t4, -1 
			sb t4, 1(t6)
			
			DONE_UP_MOVE:
			addi t6, t6, 2
			addi t2, t2, 1
			bne t2, t5, UP_MOVE_LOOP
		
		addi t1, t1, -1
		la t5, character
		sb t1, 1(t5)
		
		li a0, 1 
		j DONE_MOVE_CHARACTER
		
	LEFT_MOVE:
		li t3, 97
		bne t2, t3, DOWN_MOVE
		
		#invalid move if char is at the left of the board
		beq t0, x0, ERROR_MOVE
		
		la t6, box
		lw t6, 0(t6)
		li t2, 0 
		LEFT_MOVE_LOOP:
			lb t3, 0(t6) # box x
			lb t4, 1(t6) 
			addi t3, t3, 1

			bne t3, t0, DONE_LEFT_MOVE
			bne t4, t1, DONE_LEFT_MOVE

			addi t3, t3, -1
			beq t3, x0, ERROR_MOVE
			
			mv a1, t4 
			addi a0, t3, -1
			mv a7, ra
			jal ra, boxAtPoint
			mv ra, a7
			li a7, 1 
			beq a0, a7, ERROR_MOVE
			
			la t1, character
			lb t0, 0(t1) # x
			lb t1, 1(t1) # y 
			
			addi t3, t3, -1 
			sb t3, 0(t6)
			
			DONE_LEFT_MOVE:
			addi t6, t6, 2
			addi t2, t2, 1
			bne t2, t5, LEFT_MOVE_LOOP
		
		addi t0, t0, -1
		la t5, character
		sb t0, 0(t5)
		
		li a0, 1 
		j DONE_MOVE_CHARACTER
		
	DOWN_MOVE:
		li t3, 115
		bne t2, t3, RIGHT_MOVE
		
		#invalid move if the char is at the bottom of the board
		la t4, gridsize
		lb t4, 1(t4)
		addi t6, t4, -1
		beq t1, t6, ERROR_MOVE
		
		la t6, box
		lw t6, 0(t6)
		li t2, 0 
		DOWN_MOVE_LOOP:
			lb t3, 0(t6) # box x
			lb t4, 1(t6) 
			addi t4, t4, -1 # box y

			bne t3, t0, DONE_DOWN_MOVE
			bne t4, t1, DONE_DOWN_MOVE

			la t0, gridsize 
			lb t0, 1(t0)
			addi t0, t0, -1 
			
			addi t4, t4, 1
			beq t4, t0, ERROR_MOVE
			
			mv a0, t3 
			addi a1, t4, 1
			mv a7, ra
			jal ra, boxAtPoint
			mv ra, a7
			li a7, 1 
			beq a0, a7, ERROR_MOVE
			
			la t1, character
			lb t0, 0(t1) # x
			lb t1, 1(t1) # y 
			
			addi t4, t4, 1
			sb t4, 1(t6)
			
			DONE_DOWN_MOVE:
			addi t6, t6, 2
			addi t2, t2, 1
			bne t2, t5, DOWN_MOVE_LOOP
		
		addi t1, t1, 1
		la t5, character
		sb t1, 1(t5)
		
		li a0, 1 
		j DONE_MOVE_CHARACTER
		
	RIGHT_MOVE:
		#invalid move if the character is at the right of the board
		la t4, gridsize
		lb t4, 0(t4)
		addi t6, t4, -1
		beq t0, t6, ERROR_MOVE
		
		la t6, box
		lw t6, 0(t6)
		li t2, 0 
		RIGHT_MOVE_LOOP:
			lb t3, 0(t6) # box x
			lb t4, 1(t6) 
			addi t3, t3, -1 

			bne t3, t0, DONE_RIGHT_MOVE
			bne t4, t1, DONE_RIGHT_MOVE

			la t0, gridsize 
			lb t0, 0(t0)
			addi t0, t0, -1 
			
			addi t3, t3, 1
			beq t3, t0, ERROR_MOVE
			
			mv a1, t4 
			addi a0, t3, 1 
			mv a7, ra
			jal ra, boxAtPoint
			mv ra, a7
			li a7, 1 
			beq a0, a7, ERROR_MOVE
			
			la t1, character
			lb t0, 0(t1) # x
			lb t1, 1(t1) # y 
			
			addi t3, t3, 1 
			sb t3, 0(t6)
			
			DONE_RIGHT_MOVE:
			addi t6, t6, 2 
			addi t2, t2, 1
			bne t2, t5, RIGHT_MOVE_LOOP
		
		addi t0, t0, 1
		la t5, character
		sb t0, 0(t5)
		
		li a0, 1 
		j DONE_MOVE_CHARACTER
		
	ERROR_MOVE:
		la a0, invalidMove
		li a7, 4
		ecall
		
		li a0, 0 
	
	DONE_MOVE_CHARACTER:
		j DONE_MOVING
		
# Arguments: None 
# Returns: 1 if all boxes are on their targets 
#		   0 otherwise
#		   prints out a congratulations string if the game is over
checkGameDone:
	mv a1, ra
	jal ra, numBoxes 
	mv ra, a1
	mv t4,  a0
	
	la t2, target
	lw t2, 0(t2)
	li t3, 0 
	# for each target, check if a box exists at the same coords 
	# if not, return false
	TARGET_CHECKING:
		lb a0, 0(t2)
		lb a1, 1(t2)
		
		mv t5, ra
		jal ra, boxAtPoint
		mv ra, t5
		
		beq a0, x0, GAME_NOT_OVER
		
			
		addi t2, t2, 2 
		addi t3, t3, 1 
		bne t3, t4, TARGET_CHECKING
	
	# print finish string
	li a7, 4
	la a0, playerWonText_1 
	ecall
	li a7, 1 
	mv a0, s10 
	addi a0, a0, 1 
	ecall 
	li a7, 4 
	la a0, playerWonText_2 
	ecall 
	li a7, 1 
	mv a0, s9 
	ecall 
	li a7, 4 
	la a0, playerWonText_3 
	ecall
		
	li a0, 1 
	ret
	
	GAME_NOT_OVER:
		li a0, 0
		ret 
		
		
