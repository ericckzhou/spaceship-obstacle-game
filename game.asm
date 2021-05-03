#####################################################################
#
# CSCB58 Winter 2021 Assembly Final Project
# University of Toronto, Scarborough
#
# Student: Eric Zhou, 1006170064, zhoueri3
#
# Bitmap Display Configuration:
# - Unit width in pixels: 8 (update this as needed)
# - Unit height in pixels: 8 (update this as needed)
# - Display width in pixels: 256 (update this as needed)
# - Display height in pixels: 256 (update this as needed)
# - Base Address for Display: 0x10008000 ($gp)
#
# Which milestones have been reached in this submission?
# (See the assignment handout for descriptions of the milestones)
# - Milestone 1/2/3/4 (choose the one the applies)
# Milestone (reached): 4
#
# Which approved features have been implemented for milestone 4?
# (See the assignment handout for the list of additional features)
# 1. Smooth graphics (only erasing & updating blocks that need to be erased)
# 2. Add “pick-ups”  (adding snacks which freezes the obstacles (The World) and hp snack which increases hp by 10%=3 bars)
# 3. Scoring system (Score = # of snacks ate  MAX=99)
#
# Link to video demonstration for final submission:
# https://www.youtube.com/watch?v=2RK1F8jGhJ8
#
#Are you OK with us sharing the video with people outside course staff?
# No.
#
# Any additional information that the TA needs to know:
# - Mentioned ALL in video.
# - Pick-ups effects will not stack. (Freeze-time will not stack when its already frozen or will hp "increase" to above 100% when you gather another green hp pickup at 100% hp.
# - Spaceship movement is 2 units!
#
#####################################################################
.eqv BASE_ADDRESS 0x10008000
.eqv WAIT_TIME 40
.eqv OFFSET 128
#COLORS
.eqv BLACK 0x000000
.eqv BLUE 0x8CD3FF
.eqv DGRAY 0x607D8B
.eqv GRAY 0xB0BEC5
.eqv RED 0xDD2C00
.eqv ORANGE 0xFF8F00
.eqv YELLOW 0xFFFF00
.eqv WHITE 0xFFFFFF
.eqv GREEN 0x76FF03
.eqv FREEZE_TIME 50
#NUM OF OBSTACLES
#.eqv NUM_OBSTACLES 3

#DATA
.data
#POS = position (top-leftest position of ship)
SHIP_POS: .word  14, 0, 1792 
#ROW, COL, BASE ADDRESS OFFSET
OBST_POS: .word 0, 0, 0, 0, 0, 0, 0, 0, 0 #At least 3 meteors, stores top-left most position
#row, col, offset of address
HP: .word 10 #ingame hp
SCREEN_HP: .word 10 #hp bar on screen
OBSTACLES_DESTROYED: .word 0
TIME: .word 0
GAME_STATE: .word 1 #1 = alive, 0 = game over, 2 = frozen obstacles
SNACK: .word 0, 0, 0, 0, 0 
SNACK_COUNTER: .word 0
FREEZE_COUNTER: .word 0
#SNACK_GEN: .word 0 #1 = snack has been generated/spawned
#SNACK_TYPE: .word 0 #type of snack, freeze obstacles or extra hp (0 or 1)
#SNACK_POS: .word 0,0,0 pos, row  col
#DESIGNS
#SHIP DESIGN
#FIXED SPAWN POSITION: TOP-LEFTMOST @32x4x(32/2 - 2) = 1792 
	#G=Gray, Y=Yellow, B=black, O = orange, R=red, D= DGRAY = dark gray
	#offset--> B D D B
	#	   Y O D R
	#	   B D D B
#METEOR DESIGN
	#B G G G B
	#G D G O R
	#G G D Y O R
	#G D G O R
	#B G G G B
.text
.globl main
#==================================================================
#basic set-up in main for game then CALLS game_loop
main:
#resetting values
	la $s7, HP #DONT CHANGE s7 s6 s5!!!
	la $s6, SCREEN_HP
	la $s5, TIME
	li $t0, 10
	#reset
	sw $t0, 0($s7)
	sw $t0, 0($s6)
	la $s4, GAME_STATE
	li $t0, 1
	sw $t0, 0($s4)
	sw $zero, 0($s5)
	
	la $s0, SNACK_COUNTER
	sw $zero, 0($s0)
	la $s0, FREEZE_COUNTER
	sw $zero, 0($s0)
	
	jal clear_screen
	jal draw_hp_bar
	jal draw_ship
	la $a0, OBST_POS
	jal gen_randomized_obstacles
	jal draw_obstacles
	j game_loop
#==================================================================
#DIMENSIONS: 
#1 pixel offset: 4
#1 row offset: 128
# 4096 to last row
# ---------------------------
# Basic Features in the game:
# ---------------------------
#1. Keyboard Input/Spaceship update location
# wasd - w=77, a=61, s=73, d=64 (key in ascii)
#2. Update obstacle location
# updates in game_loop (takes in with account the WAIT_TIME, same with ship)
#3. Collision checking (also border)
#Checks every game_loop
#4. Update other game state & end of game
#Updates state at the end
#5. Erase objects from old position on screen
#Erase at the end
#6. Redraw objects in new position on screen
#Erase then redraws at new position
#==================================================================
game_loop:
	#GET_INPUT keys
	lw $s2, 0($s5) #time
	jal get_input 
	jal gen_snack
	la $s1, GAME_STATE
	lw $s0, 0($s1) #game_state
	beq $s0, 2, skip_update_obstacles
	#move obstacles
	jal update_obstacles
	jal check_collision
	j continue_game
skip_update_obstacles: #keeps updating obstacles when frozen buffed
	la $s1, FREEZE_COUNTER
	lw $s0, 0($s1)
	bgt $s0, FREEZE_TIME, remove_freeze
	add $s0, $s0, 1
	sw $s0, 0($s1)
	j continue_game
remove_freeze: #will remove the freeze snack buff
	sw $zero, 0($s1)
	la $s1, GAME_STATE
	li $s0, 1
	sw $s0, 0($s1)
continue_game:
	lw $s4, 0($s7) #HP val
	lw $s3, 0($s6) #SCREEN HP val
	bne $s4, $s3, update_hp
	jal check_snack_eaten
	jal draw_snack
	j loop_game
update_hp: #updates the screen hp bar
	lw $s4, 0($s7) #HP val
	lw $s3, 0($s6) #SCREEN HP val
	blt $s4, $s3, draw_red_ship #if HP < SCREEN_HP=> collision
	jal draw_healed_ship
	j update_hp_2
draw_red_ship:
	jal erase_obstacles
	jal gen_randomized_obstacles
	jal draw_obstacles
	jal draw_destroyed_ship
update_hp_2:
	jal update_hp_bar
	li $v0, 32
	li $a0, 300
	syscall
loop_game:
	#WAIT_TIME
	li $v0, 32
	li $a0, WAIT_TIME
	syscall
	jal draw_ship
	add $s2, $s2, 40
	sw $s2, 0($s5)
	j game_loop
#==================================================================
clear_screen: #clears entire screen
	la $t0, BASE_ADDRESS
	li $t1, BLACK
	li $t5, 0
loop_clear:
	bge $t5, 1024, exit_clear #to clear all pixels on screen (32x32=1024)
	sw $t1, 0($t0)
	addi $t5, $t5, 1
	add $t0, $t0, 4
	j loop_clear
exit_clear:
	jr $ra
	
#Note: ship would not be allowed to move ONTOP of HP bar (designer choice)
draw_hp_bar: #Writes "HP" in pixels
	li $t0, BASE_ADDRESS
	li $t1, GREEN
	li $t3, DGRAY
	li $t2, 0
	#offset 128x(32-4) = 3584
	addi $t0, $t0, 3584
	#last 3rd row offset
	move $a0, $ra
	jal loop_draw_hp_bar_outline #draws gray hp bar outline (top and bottom horizontal line)
	li $t2, 0
	jal loop_draw_hp_bar #draws green health bar
	li $t2, 0
	jal loop_draw_hp_bar_outline
	li $t0, BASE_ADDRESS
	addi $t0, $t0, 3712 #the row with the hp bar
	sw $t3, 0($t0)
	sw $t3, 124($t0) #last col = 124 offset, drawing bars that connect the hp_bar_outline top and bottom hr line
	addi $t0, $t0, 128 #next row
	sw $t3, 0($t0)
	sw $t3, 124($t0)
	jr $a0
loop_draw_hp_bar_outline:
	beq $t2, 32, exit_draw_hp_bar #loops an entire row to draw the gray row
	sw $t3, 0($t0)
	addi $t0, $t0, 4
	addi $t2, $t2, 1
	j loop_draw_hp_bar_outline
loop_draw_hp_bar:
	beq $t2, 64, exit_draw_hp_bar
	sw $t1, 0($t0)
	addi $t2, $t2, 1
	addi $t0, $t0, 4
	j loop_draw_hp_bar
exit_draw_hp_bar:
	jr $ra

#draw_ship & draw_obstacles Called at the start of the program
#draw_ship fixed position at the start
#draws based on "updated" ship_pos
#ARGS: NONE
draw_ship:
#vars
	#offset--> B D D B
	#	   Y O D R
	# 	   B D D B
	li $t0, BASE_ADDRESS
	li $t1, DGRAY
	li $t2, GRAY
	li $t3, RED
	li $t4, ORANGE
	li $t5, YELLOW
	li $t6, BLACK
	
	la $t9, SHIP_POS
	lw $t8, 8($t9)
#drawing
#first row
	add $t0, $t0, $t8
	sw $t6, 0($t0)
	sw $t1, 4($t0)
	sw $t1, 8($t0)
#second row
	addi $t0, $t0, OFFSET
	sw $t5, 0($t0)
	sw $t4, 4($t0)
	sw $t1, 8($t0)
	sw $t3, 12($t0)
#third row
	addi $t0, $t0, OFFSET
	sw $t6, 0($t0)
	sw $t1, 4($t0)
	sw $t1, 8($t0)
	jr $ra	
#==================================================================
#Random generated obstacles within the border but at the right-most generated
#Cannot be at the same position or within the meteor.
gen_randomized_obstacles:
#32-4 (hpbar) - 5 (obst height) = 23 max height total
	la $t9, OBST_POS
	addi $t8, $zero, 26 #obst 32-6= col start
	#generate randomized vals
	li $v0, 42
	li $a0, 0 #stored in a0
	li $a1, 3 #obstacles take up 5 blocks
	syscall
	move $t1, $a0 #store randomized row of first obst
	addi $t1, $t1, 1
	li $v0, 42
	li $a0, 0 
	li $a1, 2
	syscall
	add $t2, $t1, $a0
	addi $t2, $t2, 8 #store randomized row of second obst
	li $v0, 42
	li $a0, 0 
	li $a1, 2
	syscall
	add $t3, $t2, $a0
	addi $t3, $t3, 8  #store randomized row of third obst
	#storing randomized vals
	#1st obst
	sw $t1, 0($t9)
	sw $t8, 4($t9)
	sll $t1, $t1, 7 #*128 
	sll $t8, $t8, 2 #*4
	add $t1, $t1, $t8 
	sw $t1, 8($t9) #offset stored calculated by row * 128 + col * 4 (col default: 26, obst size: 6)
	#2nd obst
	addi $t8, $zero, 26
	sw $t2, 12($t9)
	sw $t8, 16($t9)
	sll $t2, $t2, 7 #*128
	sll $t8, $t8, 2 #*4
	add $t2, $t2, $t8
	sw $t2, 20($t9)
	#3rd obst
	addi $t8, $zero, 26
	sw $t3, 24($t9)
	sw $t8, 28($t9)
	sll $t3, $t3, 7 #*128
	sll $t8, $t8, 2 #*4
	add $t3, $t3, $t8
	sw $t3, 32($t9)
	#ret
	jr $ra
draw_obstacles:
#METEOR DESIGN
	#B G G G B
	#G D G O R
	#G G D Y O R
	#G D G O R
	#B G G G B
	li $t1, DGRAY
	li $t2, GRAY
	li $t3, RED
	li $t4, ORANGE
	li $t5, YELLOW
	la $t9, OBST_POS
	li $t6, 0
loop_draw_obst:
	beq $t6, 3, ret_draw_obst
	li $t0, BASE_ADDRESS
	lw $t8, 8($t9)
	add $t0, $t0, $t8 #offset
	#draw
	#1st row of obstacle
	sw $t2, 4($t0)
	sw $t2, 8($t0)
	sw $t2, 12($t0)
	#2nd row
	addi $t0, $t0, OFFSET
	sw $t2, 0($t0)
	sw $t1, 4($t0)
	sw $t2, 8($t0)
	sw $t4, 12($t0)
	sw $t3, 16($t0)
	#3rd row
	addi $t0, $t0, OFFSET
	sw $t2, 0($t0)
	sw $t2, 4($t0)
	sw $t1, 8($t0)
	sw $t5, 12($t0)
	sw $t4, 16($t0)
	sw $t3, 20($t0)
	#4th row
	addi $t0, $t0, OFFSET
	sw $t2, 0($t0)
	sw $t1, 4($t0)
	sw $t2, 8($t0)
	sw $t4, 12($t0)
	sw $t3, 16($t0)
	#5th row
	addi $t0, $t0, OFFSET
	sw $t2, 4($t0)
	sw $t2, 8($t0)
	sw $t2, 12($t0)
	#increment
	addi $t9, $t9, 12
	addi $t6, $t6, 1
	j loop_draw_obst
ret_draw_obst:
	jr $ra

#==================================================================
#At the beginning of every game_loop:
#Gets user keyboard input and calls erase_ship afterwards then return back to game_loop
#W = move ship forward by 2 unit
#A = move ship upwards by 2 unit
#S = move ship backwards by 2 unit
#D = move ship downwards by 2 unit
#DEFAULT: 2 for now.
get_input:
	li $t0, 0xffff0000 #this checks for input
	lw $t1, 0($t0)
	move $s0, $ra #storing PC back to caller $a0
	beq $t1, 1, key_pressed #==1 if key pressed
	jr $s0
key_pressed:
	lw $t1, 4($t0) #get key-input
	li $t0, BASE_ADDRESS
	la $t9, SHIP_POS
	lw $t6, 0($t9)
	lw $t7, 4($t9)
	lw $t8, 8($t9) #offset
	beq $t1, 0x70,respond_to_restart
	la $t5, GAME_STATE #will not respond to any wasd if game_state=0 => game_over
	lw $t4, 0($t5)
	beq $t4, 0, skip_key_pressed
	beq $t1, 0x77, respond_to_w
	beq $t1, 0x61, respond_to_a
	beq $t1, 0x73, respond_to_s
	beq $t1, 0x64, respond_to_d
 skip_key_pressed:
	jr $s0
respond_to_w:
#top-left block of ship (take in account -3 col b/c of tip and -2 for the 2 blocks added..) 32 - 5 = 27
	blt $t6, 2, skip_update #first row
	addi $t6, $t6, -2
	sw $t6, 0($t9)
	li $a1, -256
	j update_ship
respond_to_a:
	blt $t7, 2, skip_update
	addi $t7, $t7, -2
	sw $t7, 4($t9)
	li $a1, -8
	j update_ship
respond_to_s:
	bgt $t6, 23, skip_update 
	addi $t6, $t6, 2
	sw $t6, 0($t9)
	li $a1, 256
	j update_ship
respond_to_d:
	bgt $t7, 27, skip_update
	addi $t7, $t7, 2
	sw $t7, 4($t9)
	li $a1, 8
	j update_ship
respond_to_restart:
	j main
skip_update: #will not update when at border of the screen.
	jr $s0
#==================================================================
#Called at the end of every game_loop:
#Completely erases the ship off the screen and calls update_ship then returns back to caller (get_input)
#=> Set all pixels of ship to black
#no args
draw_destroyed_ship:
	li $t1, RED
	j draw_colored_ship #draws red ship
draw_healed_ship:
	li $t1, GREEN #draws green ship
	j draw_colored_ship
erase_ship:
	li $t1, BLACK
draw_colored_ship:
	li $t0, BASE_ADDRESS
	la $t9, SHIP_POS
	lw $t8, 8($t9)
#first row
	add $t0, $t0, $t8
	sw $t1, 4($t0)
	sw $t1, 8($t0)
#second row
	addi $t0, $t0, OFFSET
	sw $t1, 0($t0)
	sw $t1, 4($t0)
	sw $t1, 8($t0)
	sw $t1, 12($t0)
#third row
	addi $t0, $t0, OFFSET
	sw $t1, 4($t0)
	sw $t1, 8($t0)
	jr $ra
#==================================================================
#Called when either collision happens or obstacle reached end of the screen (leftmost)
erase_obstacles:
	li $t1, BLACK
	la $t9, OBST_POS
	li $t6, 0
loop_erase_obst:
	beq $t6, 3, ret_erase_obst
	li $t0, BASE_ADDRESS
	lw $t8, 8($t9)
	add $t0, $t0, $t8 #offset
	#draw
	#1st row
	sw $t1, 4($t0)
	sw $t1, 8($t0)
	sw $t1, 12($t0)
	#2nd row
	addi $t0, $t0, OFFSET
	sw $t1, 0($t0)
	sw $t1, 4($t0)
	sw $t1, 8($t0)
	sw $t1, 12($t0)
	sw $t1, 16($t0)
	#3rd row
	addi $t0, $t0, OFFSET
	sw $t1, 0($t0)
	sw $t1, 4($t0)
	sw $t1, 8($t0)
	sw $t1, 12($t0)
	sw $t1, 16($t0)
	sw $t1, 20($t0)
	#4th row
	addi $t0, $t0, OFFSET
	sw $t1, 0($t0)
	sw $t1, 4($t0)
	sw $t1, 8($t0)
	sw $t1, 12($t0)
	sw $t1, 16($t0)
	#5th row
	addi $t0, $t0, OFFSET
	sw $t1, 4($t0)
	sw $t1, 8($t0)
	sw $t1, 12($t0)
	#increment
	addi $t9, $t9, 12
	addi $t6, $t6, 1
	j loop_erase_obst
ret_erase_obst:
	jr $ra
#==================================================================
#Special case: reached end of screen
#Redraws the ship based on the updated position
#a0 = $ra, a1 = how much to add to the SHIP_POS + BASE_ADDRESS
#Returns back to caller(erase_ship)
update_ship:
	jal erase_ship
	#uses erase temp vars to save time
	add $t8, $t8, $a1
	sw $t8, 8($t9)
	jal draw_ship
	jr $s0
#==================================================================
#Moves the obstacle leftwards by 6 unit each game_loop
update_obstacles:
	move $s0, $ra
	jal erase_obstacles
	li $t6, 0
	la $t9, OBST_POS
loop_update_obst: #moves each obstacle by 1 units to the left.
	beq $t6, 3, draw_updated_obst
	#row stays the same
	lw $t7, 4($t9) #only changes col # by 1 for now.. (speed)
	lw $t8, 8($t9) #offset
	blt $t7, 1, draw_new_obst #when obstacles reaches the end <1 rows => remake
	addi $t7, $t7, -1
	sw $t7, 4($t9)
	addi $t8, $t8, -4
	sw $t8, 8($t9)
	#increment
	addi $t6, $t6, 1
	addi $t9, $t9, 12
	j loop_update_obst
draw_new_obst:
	jal gen_randomized_obstacles
	jal draw_ship
draw_updated_obst:
	jal draw_obstacles
	jr $s0
#==================================================================
#Called after updating obstacle's position and ship position (if gotten user input)
check_collision:
	move $s0, $ra
	la $t0, SHIP_POS
	la $t1, OBST_POS
	lw $t2, 0($t0) #read ship row & col
	lw $t3, 4($t0)
	addi $t2, $t2, 1 #+1 row
	addi $t3, $t3, 3 #middle ship, +3 col
	li $t7, 0
loop_check_collision:
	beq $t7, 3, no_collision #if i < 3 => not done checking all obstacles collision with spaceship
	lw $t4, 0($t1) #read obst row & col
	lw $t5, 4($t1)
	addi $t4, $t4, 2 #middle of obst row and already at front of obst
	addi $t5, $t5, 2
	jal check_obst_collision
	addi $t7, $t7, 1
	addi $t1, $t1, 12
	j loop_check_collision
	
check_obst_collision: #checking for collision
	move $s1, $ra
	sub $t6, $t2, $t4 #check row
	jal abs_value #absolute of t6
	#this checks the row and if it is < 4 then it checks the column after.
	blt $t6, 4, check_obst_collision_col 
	jr $s1
check_obst_collision_col: #checks to see if column is within the spaceship
	sub $t6, $t3, $t5
	jal abs_value #absolute of t6
	blt $t6, 3, minus_hp
	jr $s1
minus_hp: #collision occured => minus hp
#max hp = 10, dead=0
	la $t9, HP
	lw $t8, 0($t9)
	addi $t8, $t8, -1
	sw $t8, 0($t9) #new HP val
	beq $t8, 0, GAMEOVER
	jr $s1
no_collision:
	jr $s0
	
abs_value: #abs fcn
	bgtz $t6, positive
	addi $t8, $zero, -1
	mult $t6, $t8
	mflo $t6
positive: #Positive=just return
	jr $ra
update_hp_bar: #updates the hp bar depending on collision or snack eaten.
# X X X
# X X X
	li $t0, BASE_ADDRESS
	li $t1, BLACK
#Offset 128 x (32-3) = 3712
	la $t2, HP
	la $t5, SCREEN_HP
	lw $t6, 0($t5)
	lw $t3, 0($t2) #0-10, hp values
	li $t9, 0
	bgt $t3, $t6, increased_hp
	j change_bar
increased_hp: #increases hp when the green snack is eaten.
	li $t9, 1
	li $t1, GREEN
change_bar:
	sw $t3, 0($t5) #update screen hp val
	beq $t9, 1, increase_bar
	j other_bar
increase_bar: #increase hp bar!
	move $t3, $t6
other_bar: #normal collision bar
	li $t4, 12
	mult $t3, $t4
	mflo $t3 #at the edge of bar
	addi $t3, $t3, 4 #add 1 blocks to get to last 3 hp blocks (green component)
	addi $t3, $t3, 3712 
	add $t0, $t0, $t3
	#changing the bar color here!
	sw $t1, 0($t0)
	sw $t1, 128($t0)
	sw $t1, 4($t0)
	sw $t1, 132($t0)
	sw $t1, 8($t0)
	sw $t1, 136($t0)
	jr $ra
#==================================================================
#a0 is time
#gets the # of snacks eaten!
get_score:
	li $t0, 10
	div $a0, $t0 #time/10
	mflo $v0 #result
	mfhi $v1 #remainder
	jr $ra
#draw_"num" will draw the number of value $a0, at position $a3
draw_zero:
	#a0 is the val to draw
	#a3 pos to draw
	li $t0, BASE_ADDRESS
	li $t1, WHITE
	add $a3, $t0, $a3
	sw $t1, 4($a3)
	sw $t1, 8($a3)
	addi $a3, $a3, 128
	sw $t1, 0($a3)
	sw $t1, 12($a3)
	addi $a3, $a3, 128 
	sw $t1, 0($a3)
	sw $t1, 12($a3)
	addi $a3, $a3, 128 
	sw $t1, 0($a3)
	sw $t1, 12($a3)
	addi $a3, $a3, 128
	sw $t1, 4($a3)
	sw $t1, 8($a3)
	jr $ra
draw_one:
	#a0 is the val to draw
	#a2 = $ra
	#a3 pos to draw
	li $t0, BASE_ADDRESS
	li $t1, WHITE
	add $a3, $t0, $a3
	sw $t1, 8($a3)
	addi $a3, $a3, 128
	sw $t1, 4($a3)
	sw $t1, 8($a3)
	addi $a3, $a3, 128
	sw $t1, 8($a3)
	addi $a3, $a3, 128
	sw $t1, 8($a3)
	addi $a3, $a3, 128
	sw $t1, 0($a3)
	sw $t1, 4($a3)
	sw $t1, 8($a3)
	sw $t1, 12($a3)
	jr $ra
draw_two:
	li $t0, BASE_ADDRESS
	li $t1, WHITE
	add $a3, $t0, $a3
	sw $t1, 4($a3)
	sw $t1, 8($a3)
	addi $a3, $a3, 128
	sw $t1, 0($a3)
	sw $t1, 12($a3)
	addi $a3, $a3, 128
	sw $t1, 8($a3)
	addi $a3, $a3, 128
	sw $t1, 4($a3)
	addi $a3, $a3, 128
	sw $t1, 0($a3)
	sw $t1, 4($a3)
	sw $t1, 8($a3)
	sw $t1, 12($a3)
	jr $ra
draw_three:
	li $t0, BASE_ADDRESS
	li $t1, WHITE
	add $a3, $t0, $a3
	sw $t1, 0($a3)
	sw $t1, 4($a3)
	sw $t1, 8($a3)
	addi $a3, $a3, 128
	sw $t1, 12($a3)
	addi $a3, $a3, 128
	sw $t1, 4($a3)
	sw $t1, 8($a3)
	addi $a3, $a3, 128
	sw $t1, 12($a3)
	addi $a3, $a3, 128
	sw $t1, 0($a3)
	sw $t1, 4($a3)
	sw $t1, 8($a3)
	jr $ra
draw_four:
	li $t0, BASE_ADDRESS
	li $t1, WHITE
	add $a3, $t0, $a3
	sw $t1, 0($a3)
	sw $t1, 12($a3)
	addi $a3, $a3, 128
	sw $t1, 0($a3)
	sw $t1, 12($a3)
	addi $a3, $a3, 128
	sw $t1, 0($a3)
	sw $t1, 4($a3)
	sw $t1, 8($a3)
	sw $t1, 12($a3)
	addi $a3, $a3, 128
	sw $t1, 12($a3)
	addi $a3, $a3, 128
	sw $t1, 12($a3)
	jr $ra
draw_five:
	li $t0, BASE_ADDRESS
	li $t1, WHITE
	add $a3, $t0, $a3
	sw $t1, 0($a3)
	sw $t1, 4($a3)
	sw $t1, 8($a3)
	sw $t1, 12($a3)
	addi $a3, $a3, 128
	sw $t1, 0($a3)
	addi $a3, $a3, 128
	sw $t1, 0($a3)
	sw $t1, 4($a3)
	sw $t1, 8($a3)
	addi $a3, $a3, 128
	sw $t1, 12($a3)
	addi $a3, $a3, 128
	sw $t1, 0($a3)
	sw $t1, 4($a3)
	sw $t1, 8($a3)
	jr $ra
draw_six:
	li $t0, BASE_ADDRESS
	li $t1, WHITE
	add $a3, $t0, $a3
	sw $t1, 4($a3)
	sw $t1, 8($a3)
	addi $a3, $a3, 128
	sw $t1, 0($a3)
	addi $a3, $a3, 128
	sw $t1, 4($a3)
	sw $t1, 8($a3)
	addi $a3, $a3, 128
	sw $t1, 0($a3)
	sw $t1, 12($a3)
	addi $a3, $a3, 128
	sw $t1, 4($a3)
	sw $t1, 8($a3)
	jr $ra
draw_seven:
	li $t0, BASE_ADDRESS
	li $t1, WHITE
	add $a3, $t0, $a3
	sw $t1, 4($a3)
	sw $t1, 8($a3)
	sw $t1, 12($a3)
	addi $a3, $a3, 128
	sw $t1, 0($a3)
	sw $t1, 12($a3)
	addi $a3, $a3, 128
	sw $t1, 8($a3)
	addi $a3, $a3, 128
	sw $t1, 8($a3)
	addi $a3, $a3, 128
	sw $t1, 4($a3)
	jr $ra
draw_eight:
	li $t0, BASE_ADDRESS
	li $t1, WHITE
	add $a3, $t0, $a3
	sw $t1, 4($a3)
	sw $t1, 8($a3)
	addi $a3, $a3, 128
	sw $t1, 0($a3)
	sw $t1, 12($a3)
	addi $a3, $a3, 128
	sw $t1, 4($a3)
	sw $t1, 8($a3)
	addi $a3, $a3, 128
	sw $t1, 0($a3)
	sw $t1, 12($a3)
	addi $a3, $a3, 128
	sw $t1, 4($a3)
	sw $t1, 8($a3)
	jr $ra
draw_nine:
	li $t0, BASE_ADDRESS
	li $t1, WHITE
	add $a3, $t0, $a3
	sw $t1, 4($a3)
	sw $t1, 8($a3)
	addi $a3, $a3, 128
	sw $t1, 0($a3)
	sw $t1, 12($a3)
	addi $a3, $a3, 128
	sw $t1, 4($a3)
	sw $t1, 8($a3)
	sw $t1, 12($a3)
	addi $a3, $a3, 128
	sw $t1, 12($a3)
	addi $a3, $a3, 128
	sw $t1, 12($a3)
	jr $ra
#END OF DRAWING SCORES FUNCTION
#=========================================================
#a0 = first digit
#a1 = second digit
#max score: 99
#DRAWS THE FIRST DIGIT (TENS)
draw_score:
	addi $a3, $zero, 2092 #16th row to draw + offset 44
	beq $a0, 0, draw_zero
	beq $a0, 1, draw_one
	beq $a0, 2, draw_two
	beq $a0, 3, draw_three
	beq $a0, 4, draw_four
	beq $a0, 5, draw_five
	beq $a0, 6, draw_six
	beq $a0, 7, draw_seven
	beq $a0, 8, draw_eight
	beq $a0, 9, draw_nine
	jr $ra #undefined
#DRAWS THE SECOND DIGIT (ONES)
draw_second_score:
	move $a0, $a1
	addi $a3, $zero, 2116 #16th row to draw + offset 44 + 24
	beq $a0, 0, draw_zero
	beq $a0, 1, draw_one
	beq $a0, 2, draw_two
	beq $a0, 3, draw_three
	beq $a0, 4, draw_four
	beq $a0, 5, draw_five
	beq $a0, 6, draw_six
	beq $a0, 7, draw_seven
	beq $a0, 8, draw_eight
	beq $a0, 9, draw_nine
	jr $ra	#undefined
#===============================================================================
#Will generate a snack to spawn 
gen_snack:
	la $t0, SNACK
	lw $t1, 0($t0) #1st index to check if generated yet
	beq $t1, 1, check_snack_eaten #already generated== 1 => check if its eaten
	li $t9, BASE_ADDRESS
	#gen randomized num to determine which snack to spawn
	li $v0, 42
	li $a0, 0
	li $a1, 2
	syscall
	blt $a0, 1, gen_freeze
	#otherwise, gen_hp snack
	li $t2, GREEN
	li $t3, 1
	sw $t3, 4($t0)
	j spawn_snack
#freeze snack
gen_freeze:
	li $t2, BLUE
	sw $zero,4($t0)
#draws snack on screen based on randomized row and column
spawn_snack:
#t3 = row, t4 = col
	#get randomized row
	li $v0, 42
	li $a0, 0
	li $a1, 16
	syscall
	move $t3, $a0 #row
	addi $t3, $t3, 1
	#get randomized column
	li $v0, 42
	li $a0, 0
	li $a1, 16 #col
	syscall
	move $t4, $a0
	addi $t4, $t4, 1
	#store in snack pos (at the end of array)
	sw $t3, 12($t0) #storing row and col
	sw $t4, 16($t0)
	sll $t3, $t3, 7 #mul by 128
	sll $t4, $t4, 2 #mul by 4
	add $t3, $t3, $t4 #total offset
	sw  $t3, 8($t0)#store position
	add $t3, $t3, $t9 #offsetted address..
	li $t1, 1 #change the "generated" value to spawned = 1 = true
	sw $t1, 0($t0) #indicate that it has been spawned
	j snack_ret
#checks to see if the snack has been eaten .
check_snack_eaten:
	la $t0, SHIP_POS
	la $t1, SNACK
	lw $t2, 0($t0) #spaceship rows & cols
	lw $t3, 4($t0)
	addi $t2, $t2, 1 #getting it centered!
	addi $t3, $t3, 1
	lw $t4, 12($t1)  #snack rows & cols
	lw $t5, 16($t1)
	sub $t6, $t2, $t4 #getting the abs row difference b/w them 
	abs $t6, $t6
	sub $t7, $t3, $t5 #getting the abs col difference b/w them
	abs $t7, $t7
	blt $t6, 2, check_col #checks if row is within range
	j snack_ret
#checks if col is within range
check_col:
	blt $t7, 3, get_eaten
	j snack_ret
get_eaten: #note: will not refreeze if already in freeze => cheating!!!
	sw $zero, 0($t1)
	lw $t3, 12($t1) #storing row and col
	lw $t4, 16($t1)
	sll $t3, $t3, 7 #mul by 128
	sll $t4, $t4, 2 #mul by 4
	add $t3, $t3, $t4
	add $t3, $t3, BASE_ADDRESS #offsetted address...
	li $t5, BLACK
	sw $t5, 0($t3) #erasing snack
	li $t9, 0
	sw $t9, 0($t1) 
	li $t9, 1
	sw $t9, 8($t1)
	lw $t2, 4($t1) #check type
	la $t0, SNACK_COUNTER #increment snack counter
	lw $t1, 0($t0)
	add $t1, $t1, 1 #increase snack counter by 1
	sw $t1, 0($t0) #update counter
	beq $t2, 1, gain_hp #HP SNACK
	la $t0, GAME_STATE #FREEZE SNACK
	li $t9, 2
	sw $t9, 0($t0) #change the game state to 2 => frozen state
	j gen_snack #generates a new snack as old one was eaten\
#hp snack eaten
gain_hp:
	la $t0, HP
	lw $t9, 0($t0)
	beq $t9, 10, max_hp
	add $t9, $t9, 1 #increase hp by 1 => 10%
	sw $t9, 0($t0)
#checks to see if ship already max hp => does nothing (snack)
max_hp:
	j snack_ret
#draws the snack
draw_snack:
	la $t0, SNACK
	li $t9, BASE_ADDRESS
	lw $t3, 12($t0) #storing row and col
	lw $t4, 16($t0)
	sll $t3, $t3, 7#calc row offset
	sll $t4, $t4, 2 #calc col offset
	add $t3, $t3, $t4
	add $t3, $t3, $t9 #offsetted address...
	lw $t5, 4($t0)
	beq $t5, 1, set_block_green
	li $t2, BLUE
	j set_snack
set_block_green:
	li $t2, GREEN
set_snack:
	sw $t2, 0($t3)
snack_ret: 
 	jr $ra

#=============================================================================
#gameover initialization
GAMEOVER:
	jal update_hp_bar #final hp bar (0)
	jal draw_destroyed_ship #red ship
	li $v0, 32
	li $a0, 500 #0.5 sec wait of death screen
	syscall
	la $t0, GAME_STATE
	li $t1, 0
	sw $t1, 0($t0)
draw_gameover: #draws game over screen
	jal clear_screen 
	li $t0, BASE_ADDRESS
	li $t1, WHITE
	#First 4 = GAME
	#1st row of game over
	sw $t1, 28($t0)
	sw $t1, 32 ($t0)
	sw $t1, 36 ($t0)
	sw $t1, 48($t0)
	sw $t1, 52($t0)
	sw $t1, 68($t0)
	sw $t1, 76($t0)
	sw $t1, 92($t0)
	sw $t1, 96($t0)
	#2nd row
	addi $t0, $t0, 128
	sw $t1, 24($t0)
	sw $t1, 44($t0)
	sw $t1, 56($t0)
	sw $t1, 64($t0)
	sw $t1, 72($t0)
	sw $t1, 80($t0)
	sw $t1, 88($t0)
	sw $t1, 100($t0)
	#3rd row
	addi $t0, $t0, 128
	sw $t1, 24($t0)
	sw $t1, 32($t0)
	sw $t1, 36($t0)
	sw $t1, 44($t0)
	sw $t1, 48($t0)
	sw $t1, 52($t0)
	sw $t1, 56($t0)
	sw $t1, 64($t0)
	sw $t1, 72($t0)
	sw $t1, 80($t0)
	sw $t1, 88($t0)
	sw $t1, 92($t0)
	sw $t1, 96($t0)
	sw $t1, 100($t0)
	#4th row
	addi $t0, $t0, 128
	sw $t1, 24($t0)
	sw $t1, 36($t0)
	sw $t1, 44($t0)
	sw $t1, 56($t0)
	sw $t1, 64($t0)
	sw $t1, 72($t0)
	sw $t1, 80($t0)
	sw $t1, 88($t0)
	#5th row
	addi $t0, $t0, 128
	sw $t1, 28($t0)
	sw $t1, 32 ($t0)
	sw $t1, 36 ($t0)
	sw $t1, 44($t0)
	sw $t1, 56($t0)
	sw $t1, 64($t0)
	sw $t1, 80($t0)
	sw $t1, 92($t0)
	sw $t1, 96($t0)
	sw $t1, 100($t0)
	
	#7th row - OVER
	addi $t0, $t0, 128
	addi $t0, $t0, 128
	sw $t1, 28($t0)
	sw $t1, 32($t0)
	sw $t1, 44($t0)
	sw $t1, 60($t0)
	sw $t1, 72($t0)
	sw $t1, 76($t0)
	sw $t1, 92($t0)
	sw $t1, 96($t0)
	#8th row
	addi $t0, $t0, 128
	sw $t1, 24($t0)
	sw $t1, 36($t0)
	sw $t1, 44($t0)
	sw $t1, 60($t0)
	sw $t1, 68($t0)
	sw $t1, 80($t0)
	sw $t1, 88($t0)
	sw $t1, 100($t0)
	#9th row
	addi $t0, $t0, 128
	sw $t1, 24($t0)
	sw $t1, 36($t0)
	sw $t1, 48($t0)
	sw $t1, 56($t0)
	sw $t1, 68($t0)
	sw $t1, 72($t0)
	sw $t1, 76($t0)
	sw $t1, 80($t0)
	sw $t1, 88($t0)
	#10th row
	addi $t0, $t0, 128
	sw $t1, 24($t0)
	sw $t1, 36($t0)
	sw $t1, 48($t0)
	sw $t1, 56($t0)
	sw $t1, 68($t0)
	sw $t1, 88($t0)
	#11th row
	addi $t0, $t0, 128
	sw $t1, 28($t0)
	sw $t1, 32($t0)
	sw $t1, 52($t0)
	sw $t1, 72($t0)
	sw $t1, 76($t0)
	sw $t1, 80($t0)
	sw $t1, 88($t0)
EXIT:
#calc
	la $t0, SNACK_COUNTER #get snack counter & print it on screen to show user score.
	lw $a0, 0($t0)
	#sends a0 as arg
	jal get_score
	move $a0, $v0
	move $a1, $v1
	jal draw_score
	jal draw_second_score
restart_loop: #waiting for user input 'p' to be pressed to restart
	jal get_input 
	j restart_loop

