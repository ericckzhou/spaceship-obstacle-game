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
# Milestone (reached): 
#
# Which approved features have been implementedfor milestone 4?
# (See the assignment handout for the list of additional features)
# 1. (fill in the feature, if any)
# 2. (fill in the feature, if any)
# 3. (fill in the feature, if any)
# ... (add more if necessary)
#
# Link to video demonstration for final submission:
# - (insert YouTube / MyMedia / other URL here). Make sure we can view it!
#
#Are you OK with us sharing the video with people outside course staff?
# - yes / no / yes, and please share this project githublink as well!
#
# Any additional information that the TA needs to know:
# - (write here, if any)
#
#####################################################################
.eqv BASE_ADDRESS 0x10008000
.eqv WAIT_TIME 40
.data
.text
.globl main
main:
#COLORS
#ORANGE: FF8F00
#YELLOW: FFFF00
#RED: DD2C00
#DARKGRAY: 607d8b
#GRAY: B0BEC5
#NEED TO STORE POSITION OF THE SHIP
#POSITION OF METEORITE...
	#Creating spaceship
	#G=Gray (t0), Y=Yellow, B=black, O = orange, R=red, D= dark gray/blue
	# B D D D Y
	# O D G D D
	# B G G G R R
	# O D G D D
	# B D D D Y
	#Spawned in the middle of the screen
	#1 pixel = 4 bytes
	#Unit width/height (pixel): 8 
	#Screen width/height (pixel): 256
	#=> 256/8 = 32
	#so 32x32 unit wide
	#Offset of 1 unit: 4 bytes
	#Offset of 1 row (32 unit): 32 x (4 bytes) = 128
	#Middle: 32 x 4 x (32/2) = 2048
	li $t0, BASE_ADDRESS #for screen top-left
	li $t1, 0x00696969 #gray
	li $t2, 0x00FFFF00 #yellow
	#One row above middle
	#32x4x(32/2 - 1) = 1920
	sw $t2, 1920($t0)
	sw $t1, 1924($t0)
	sw $t1, 1928($t0)
	sw $t1, 1932($t0)
	#Middle
	sw $t1, 2052($t0)
	sw $t1, 2056($t0)
	sw $t1, 2060($t0)
	#One row below middle
	#32x4x(32/2 + 1) = 2176
	sw $t2, 2176($t0)
	
	sw $t1, 2180($t0)
	sw $t1, 2184($t0)
	sw $t1, 2188($t0)
	
	#METEOR DESIGN
	#G=gray, D=dark gray, B=black, R=red, Y=yellow, O=orange
	#B G G G B
	#G D G O R
	#G G D Y O R
	#G D G O R
	#B G G G B
game: #main loop
	#Getting User Input
	#Address stored in $t9
	li $t9, 0xffff0000
	lw $t8, 0($t9)
	beq $t8, 1, key_pressed
	
	#SLEEP
	li $v0, 32
	li $a0, WAIT_TIME   # Wait one second (1000 milliseconds)
	syscall
	j game

key_pressed:
	lw $t4, 4($t9)
	beq $t2, 0x61, respond_to_a
respond_to_a:
	
	
	

exit:
	li $v0, 10
	syscall

