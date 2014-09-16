
# mp1.S - missile-command version
# Good luck, and have fun!

.data
	
    # Constants for accessing the fields of a struct missile, 
    # struct missile is defined in rtc.h and mp1.h

	NEXT 	  = 0
	X	  = 4
	Y	  = 8
	VX	  = 12
	VY	  = 16
	DEST_X	  = 20
	DEST_Y	  = 24
	EXPLODED  = 28
	C	  = 32

    # Character to draw for an explosion - '@'

	EXPLOSION = 64
	SPACE = 32
	SHIFT_SIZE = 16
	


# Data shared between this file and rtc.c helper functions

# This '.globl' directive makes these symbols visible externally
.globl mp1_missile_list, base_alive, mp1_score

mp1_missile_list:	.long 0x0	# Head of list pointer
base_alive:		.long 0x0	# Array of 3 bytes, plus a padding byte
mp1_score:		.long 0x0	# Player's current score


# Data private to this  file

base_pic:     	    .string "/^^^\\"	# Picture of a live base
dead_base_pic: 	    .string "xxxxx"	# Picture of a dead base
crosshairs_x:		.long 0x0	# X-position of the crosshairs
crosshairs_y:		.long 0x0	# Y-position of the crosshairs
.text

# void mp1_poke(void);
# You can use this function to write to video memory.
# 
# Interface: Register-based arguments (not C-style)
#    Inputs: %cl  - The byte you wish to write
#            %eax - Offset from the start of video memory that you wish
#                   to write to
#   Outputs: Text-mode video screen is written to at location %eax with
#            the byte in %cl
# Registers: Clobbers EDX

mp1_poke:
		movl    vmem_base_addr(,1),%edx
		movb    %cl,(%edx,%eax,1)
		ret

#   ----------------- Exported functions ---------------------

# void mp1_rtc_tasklet(unsigned long garbage);
# Performs three tasks:
#	(1) updates the list of missiles (implement this in update_missiles,
#           below, and call it from here).
#	(2) Redraw the bases - they may have been overwritten with missiles
#	(3) Redraw the crosshairs - it may have been overwritten with missiles
# Inputs   : none
# Outputs  : none
# Registers: Standard C calling convention

.globl mp1_rtc_tasklet

#In my tasklet, I call three different functions (callee-save), update_missiles, update_bases, and update_crosshairs 
mp1_rtc_tasklet:	
	pushl %ebp				#push base pointer
	movl %esp, %ebp 		#set stack pointer to the base pointer
	
	pushl %ebx
	pushl %eax				#save callee registers
	pushl %ecx				#save callee registers	
	pushl %edx				#save register	
	pushl %esi
	pushl %edi
	call update_missiles	#Calls update_missiles
	popl %edi			
	popl %esi
	popl %edx
	popl %ecx
	popl %eax
	popl %ebx

	pushl %eax				#save callee registers
	pushl %ebx				#save callee registers
	pushl %ecx				#save callee registers	
	pushl %edx				#save register	
	pushl %esi
	pushl %edi
	call update_bases		#calls updates_bases
	popl %edi
	popl %esi
	popl %edx
	popl %ecx
	popl %ebx
	popl %eax

	
	pushl %eax				#save callee registers
	pushl %ebx				#save callee registers
	pushl %ecx				#save callee registers	
	pushl %edx				#save register	
	pushl %esi
	pushl %edi			#save register
	call update_crosshairs	#calls update_crosshairs
	popl %edi 
	popl %esi
	popl %edx
	popl %ecx
	popl %ebx
	popl %eax				#pop callee saved registers (reverse order)
	leave	
		ret

# int mp1_ioctl(unsigned long arg, unsigned int cmd)
# The dispatch function for the MP1 ioctls - should use the cmd argument
# and a jumptable to execute one of the specific ioctls implemented below.
# Inputs   : unsigned long arg - parameter to the mp1_ioctl_....
#          : unsigned int cmd  - specifies which mp1_ioctl_... function 
#          :                     to execute
# Outputs  : Returns an integer - depends on which ioctl() function is called
# Registers: Standard C calling convention

.globl mp1_ioctl
mp1_ioctl:
	movl 8(%esp), %eax		#eax gets the argument value	
	cmpl $0, %eax			#See if cmd is <0
	jl invalid
	cmpl $4, %eax			#see if cmd >4
	jg invalid
	jmp *jump_table(,%eax,4) 
	jmp end
	invalid:
	movl $-1, %eax			#set return value to -1 if cmd is invalid.
	end:
		ret

# ----------------- Functions private to this file -------------------
#This function keeps track of my missile linked list and is able to analyze it's current state to perform the correct actions.
update_missiles:
	pushl %ebp				#saves base pointer
	movl %esp, %ebp			#set stack pointer to base pointer value
	
	movl mp1_missile_list,%ebx	#save head pointer address as ebx
	cmpl $0, %ebx			#is the list empty?
	je update_end			#if it is, go immediately to the end

#1. sees if missile is off grid, missile reaches destination, missile is currently exploding,missile in transit.
missile_Iteration:

	State_Check: 
	#1) Is Missile Exploding:
		cmpl $0, EXPLODED(%ebx)		#if exploded = 0, missile has not exploded
		jne missile_exploded		#go to missile exploded
	#2) Is Missile off grid:
		movl X(%ebx), %eax		#eax = x coord
		shrl $16, %eax			#shift the x coordinate 16 bits
		cmpl $0, %eax			#if x coord <0
		jl remove_missile		#missile is off-grid
		cmpl $79, %eax 			#if x coord >79
		jg remove_missile		#missile is off-grid
		
		movl Y(%ebx), %esi		#esi = y coord
		shrl $16, %esi		
		cmpl $0, %esi			#if y coord <0
		jl remove_missile		#missile is off-grid
		cmpl $24, %esi  		#if y coord <24
		jg remove_missile
		jmp dest_Check			#missile passes all three conditions, and can Dest_Check:
		
	remove_missiles:			# calls removal of the missile
		pushl %eax				#save callee registers
		pushl %ebx				#save callee registers
		pushl %ecx				#save callee registers	
		pushl %edx				#save register	
		pushl %esi
		pushl %edi
		call remove_missile		#Calls update_missiles
		popl %edi
		popl %esi
		popl %edx
		popl %ecx
		popl %ebx
		popl %eax
		jmp end_to_loop			#removes the missile from the linked list and frees the memory.
	
	
	#3) Is Missile at Destination: first I check if the x is at the destination, if it isn't then I don't need to check the Y.
	dest_Check:	
		movl X(%ebx), %eax
		sarl $16, %eax
		cmpl %eax, DEST_X(%ebx)		#compare x coord with x dest
		jne update					
		movl Y(%ebx), %esi
		sarl $16, %esi
		cmpl %esi, DEST_Y(%ebx)		#compare y coord with y dest
		jne update
		
	missile_exploded:
		pushl %eax
		pushl %ecx				#save callee registers	
		pushl %edx				#save register	
		pushl %esi
		pushl %edi
		pushl %ebx				#save register	1st arg	
		call missile_explode	#Calls update_missiles -> See's if any damage, which will return a non-zero. Else zero.
		popl %ebx				#save return value
		popl %edi
		popl %esi
		popl %edx
		popl %ecx
		popl %eax
		cmpl $0, %eax
		je no_notify_print
		call mp1_notify_user
		
		no_notify_print:
		decl EXPLODED(%ebx)			#dec exploded value
		cmpl $0,EXPLODED(%ebx)		#sees is explode is zero.
		jg explode 				#missile is used
		movl Y(%ebx), %esi		#esi = y coord
		movl X(%ebx), %eax		#eax = x coord 
		shrl $16, %eax
		shrl $16, %esi
		imull $160, %esi		#
		imull $2, %eax			#		
		addl %esi, %eax			
		movb $32, %cl			#Assuming missile is either moving or exploding,
		pushl %edx
		call mp1_poke			#missile moves to the m.-> Prints new missile location
		popl %edx
		jmp remove_missiles
		explode:
		movl Y(%ebx), %esi		#esi = y coord
		movl X(%ebx), %eax		#eax = x coord 
		shrl $16, %eax
		shrl $16, %esi
		imull $160, %esi		#
		imull $2, %eax			#		
		addl %esi, %eax			
		movb $64, %cl			#Assuming missile is either moving or exploding,
		pushl %edx
		call mp1_poke			#missile moves to the m.-> Prints new missile location
		popl %edx
		jmp explode_loop
	#4) Missile is fine with smooth sailing
	update:	 #Adds velocity to current position. And makes current position a space.

		movl Y(%ebx), %esi		#esi = y coord
		movl X(%ebx), %eax		#eax = x coord 
		shrl $16, %eax
		shrl $16, %esi
		imull $160, %esi		#
		imull $2, %eax			#		
		addl %esi, %eax					
		movb $32, %cl			#Assuming missile is either moving or exploding,
		pushl %edx
		call mp1_poke			#replace old position with a space.	
		popl %edx

		movl VX(%ebx), %esi
		addl %esi, X(%ebx)		# add's Vx to X coord

		movl VY(%ebx), %esi
		addl %esi, Y(%ebx)		# add's Vx to Y coord

		movl X(%ebx), %esi 		#esi = x coord
		movl Y(%ebx), %eax		#eax = y coord
		shrl $16, %eax
		shrl $16, %esi
		imull $2, %esi	
		imull $160, %eax
		addl %esi, %eax	
		movb C(%ebx), %cl			#Assuming missile is either moving or exploding,\
		pushl %edx
		call mp1_poke			#missile moves to the m.-> Prints new missile location
		popl %edx
 	explode_loop:	
		movl (%ebx),%ebx
	end_to_loop:
		cmpl $0,%ebx			#see if next points to the tail
		jne State_Check
	update_end:
		leave
		ret
		
#void remove_missile(int * missile)
# removes the following missile from the linked list
# Inputs   : int * missile - pointer to the specific missile we'd like to remove....

# Outputs  : 
# Registers: %ebp - missile pointer, %eax - pointer to the missile right before the current, %esi - to see if eax next is the current missile.
remove_missile: #%ebx is the pointer to the linked list.
	pushl %ebp				#saves base pointer
	movl %esp, %ebp			#set stack pointer to base pointer value
	movl mp1_missile_list, %eax
	cmpl %eax, %ebx
	je head_remove	
	
	missile_trans:
	movl NEXT(%eax), %esi		#esi <- eax Next.
	cmpl %esi, %ebx				#sees if eax <- next is our current missile.
	je	remove					#if esi = current missile, go to it's remove
	movl %esi, %eax				#eax is now current missile
	jmp missile_trans
	
	remove:
	movl NEXT(%esi), %ebx		#ebx now points at the missile behind the one that needs removing
	movl %ebx, NEXT(%eax)
	pushl %eax				#save callee registers
	pushl %ebx				#save callee registers
	pushl %ecx				#save callee registers	
	pushl %edx				#save register
	pushl %edi
	pushl %esi
	call mp1_free	
	popl %esi
	popl %edi
	popl %edx
	popl %ecx
	popl %ebx
	popl %eax
	jmp return
	
	head_remove:
	movl NEXT(%ebx), %esi
	movl %esi, mp1_missile_list	#head now points to the current->next
	movl mp1_missile_list, %ebx			#update my missile pointer as well

	pushl %esi				#save callee registers
	pushl %ebx				#save callee registers
	pushl %ecx				#save callee registers	
	pushl %edx				#save register
	pushl %edi
	pushl %eax
	call mp1_free	
	popl %eax
	popl %edi
	popl %edx
	popl %ecx
	popl %ebx
	popl %esi
	
	return:
	leave	
		ret
# void update_bases()
# Creates the image of bases on the screen.
# It will change the bases between being alive and dead.
# Inputs   : images files for the bases
# Outputs  : prints to the screen
# Registers: %ebx - points to the images, %eax - arithematic temp variable to calculate the offset.
update_bases:
	pushl %ebp
	movl %esp, %ebp
	pushl %ebx


	base_1:
	leal base_pic, %ebx			#ebx value of dead_base pic
	movl $0x000000FF, %esi
	andl base_alive, %esi		#get the address of base alive
	movl $18, %edi				#edi has 18 in it
	cmpl $0, %esi				#if the first byte of alive is zero.
	jne print_one
	leal dead_base_pic, %ebx			#ebx has the address of alive base pic\

	print_one:
	movl %edi, %eax				#eax now has the x coordinate
	imull $2, %eax				#doing the offset
	addl  $3840, %eax				#eax has the position of the base
	movb (%ebx),%cl				#%cl gets the ascii value at addr ecx(picture)
	pushl %edx
	call mp1_poke				#eax offset from start of video memory, %cl ASCII code of character to write. y*80*2+x*2 = offse
	popl %edx
	incl %ebx
	incl %edi					#increment the x position.
	cmpl $23,%edi				
	jl print_one				
	
	base_2:
	leal base_pic, %ebx			#edx value of dead_base pic
	movl $0x0000FF00, %esi
	andl base_alive, %esi		#get the address of base alive
	movl $38, %edi				#edi has 18 in it
	cmpl $0, %esi				#if the first byte of alive is zero.
	jne print_two
	leal dead_base_pic, %ebx	#ecx has the address of alive base pic

	print_two:
	movl %edi, %eax				#eax now has the x coordinate
	imull $2, %eax				#doing the offset
	addl $3840, %eax			#eax has the position of the base
	
	movb (%ebx),%cl				#%cl gets the ascii value at addr ecx(picture)
	pushl %edx
	call mp1_poke				#eax offset from start of video memory, %cl ASCII code of character to write. y*80*2+x*2 = offse
	popl %edx
	incl %ebx
	incl %edi					#increment the x position.
	cmpl $43,%edi				
	jl print_two
	
	base_3:
	leal base_pic, %ebx			#ecx value of dead_base pic
	movl $0x00FF0000, %esi
	andl base_alive, %esi		#get the address of base alive
	movl $58, %edi				#edi has 18 in it
	cmpl $0, %esi				#if the first byte of alive is zero.
	jne print_three
	leal dead_base_pic, %ebx			#ecx has the address of alive base pic\

	print_three:
	movl %edi, %eax				#eax now has the x coordinate
	imull $2, %eax				#doing the offset
	addl $3840, %eax			#eax has the position of the base
	
	movb (%ebx),%cl				#%cl gets the ascii value at addr ecx(picture)
	pushl %edx
	call mp1_poke				#eax offset from start of video memory, %cl ASCII code of character to write. y*80*2+x*2 = offse
	popl %edx
	incl %ebx
	incl %edi					#increment the x position.
	cmpl $63,%edi				
	jl print_three
	popl %ebx
	leave
		ret
# void update_crosshair()
# Updates the position of the crosshair by drawing its new position
# Inputs   :
# Outputs  : prints to the screen
# Registers: %eax - holds x value, and acts as arithematic temp. %edx - holds y value.
update_crosshairs:
	pushl %ebp					#saves base pointer
	movl %esp, %ebp				#base pointer has new stack
	
	movl crosshairs_x, %eax
	movl crosshairs_y, %edx

	imull $160, %edx			#creating offset coordinates
	imull $2, 	%eax
	addl %edx, 	%eax
	movb $43, %cl				#draws new crosshair
	pushl %edx
	call mp1_poke		
	popl %edx

	leave
		ret

mp1_ioctl_startgame:
	movl $40, crosshairs_x		#initializes crosshair x to 40
	movl $12, crosshairs_y 		#initializes crosshair y to 12
	movl $0x00FFFFFF, base_alive		# Initialize all bases to be alive.
	movl $0x0, mp1_missile_list 
	movl $0x0, mp1_score 
		ret

mp1_ioctl_addmissile: 
#callee-save registers, set up stack fram
	pushl %ebp
	movl %esp, %ebp
	pushl %ebx
	movl 8(%ebp), %esi			# pointer to missile struct
	
	pushl $33					#size of missile struct
	call mp1_malloc				#malloc(33)
	addl $4, %esp
	movl %eax, %ebx				# edx now has the addr of the free space
	cmpl $0, %ebx				# see if the return address is 0, then 
	je copy_failed				# if memory was not allocated
	
	pushl $33					# size of missile struct
	pushl %esi					#*from
	pushl %ebx					#*to
	call mp1_copy_from_user
	addl $12, %esp				#moves my stack up 3 addresses (compensates for the 3 pops)
	cmpl $0, %eax				#has the number of bits not copied.
	jne copy_failed				#if it returns a non-zero, it failed.
	
	movl mp1_missile_list ,%eax	# eax points to head
	movl %eax, NEXT(%ebx)		# ebx->next = where head is pointing
	movl %ebx, mp1_missile_list  # now head->points to the new addr of missiles.
	
	movl $0, %eax				#Copy succeeded, returns 0.
	jmp finish_adding

	copy_failed:				#copy from user fail
	pushl %eax				#save callee registers
	pushl %esi				#save callee registers
	pushl %ecx				#save callee registers	
	pushl %edx				#save register
	pushl %edi
	pushl %ebx
	call mp1_free	
	popl %ebx
	popl %edi
	popl %edx
	popl %ecx
	popl %esi
	popl %eax
	movl $-1, %eax				# return -1 because it failed.
	addl $4, %esp
	finish_adding:
	popl %ebx
	leave
		ret

mp1_ioctl_movexhairs:

	movl crosshairs_x, %eax
	movl crosshairs_y, %esi
	imull $2, %eax
	imull $160, %esi
	addl %esi, %eax				
	movb $32, %cl				#Makes old crosshair coordinate a space
	pushl %edx
	call mp1_poke
	popl %edx
	
	movl 4(%esp), %edx			#edx has the value of the arg
	shll $16, %edx				
	sarl $16, %edx				#edx has the lower bits -> x change( shift left then right)
	movl 4(%esp), %edi			#edi is the high bits -> y change (shift right)
	sarl $16, %edi				# shift edi to the right by 2 bytes. Now x and y are just signed numbers.
	
	addl %edx, crosshairs_x		#adds the change in x to crosshair x
	addl %edi, crosshairs_y		#adds the change in y to crosshair y
	
	constraint_loop:		# makes sure the cross hair coordinates are within the limits
	cmpl $0, crosshairs_x
	jl min_x
	cmpl $79, crosshairs_x	
	jg max_x
	cmpl $0, crosshairs_y
	jl min_y
	cmpl $24, crosshairs_y
	jg max_y
	jmp cross_done
	
	min_x:				# any coordinate not within the limits are replace.
	movl $0, crosshairs_x
	jmp constraint_loop
	max_x:
	movl $79, crosshairs_x
	jmp constraint_loop
	min_y:
	movl $0, crosshairs_y
	jmp constraint_loop
	max_y:
	movl $24, crosshairs_y
	
	cross_done:

	xorl %eax, %eax			#returns 0
		ret

mp1_ioctl_getstatus:

	#I use the stack to do copy_to_user
	pushl %ebp
	movl %esp, %ebp
	movl 8(%ebp), %esi			#pointer to the to*

	xor %ecx, %ecx
	movl $0x000000FF, %edx
	andl base_alive, %edx		#see if base 1 is alive
	cmpl $0, %edx 
	je base_2_life
	addl $1, %ecx
	
	base_2_life:
	shll $1, %ecx
	movl $0x0000FF00, %edx
	andl base_alive, %edx		#get the address of base alive
	cmpl $0, %edx
	je base_3_life
	addl $1, %ecx

	base_3_life:
	shll $1, %ecx
	movl $0x00FF0000, %edx		
	andl base_alive, %edx		#get the address of base alive
	cmpl $0, %edx				#see's if the base is a live or dead
	je score_update			
	addl $1, %ecx
	
	score_update:
	shll $16, %ecx
	movzwl mp1_score, %ebx		#zero extends the score 
	addl %ebx, %ecx
	pushl %ecx					#pushes the value of the score and base lives to the stack
	movl %esp, %edi				# edi points to where these values are kept
	
	pushl $4					# 4 bytes, the size of what's being copied.
	pushl %edi					# from where 
	pushl %esi					# to the address!
	call mp1_copy_to_user
	popl %esi
	popl %edi
	addl $4, %esp	
	popl %ecx
	cmpl $0, %eax
	je success			
	
	pushl %eax				#save callee registers
	pushl %ebx				#save callee registers
	pushl %ecx				#save callee registers	
	pushl %edx				#save register
	pushl %edi
	pushl %esi
	call mp1_free	
	popl %esi
	popl %edi
	popl %edx
	popl %ecx
	popl %ebx
	popl %eax
	
	movl $-1, %eax				# return -1 because it failed.
	leave 
	ret
	
	success:
	movl $0, %eax
	leave
		ret
mp1_ioctl_endgame:
	movl mp1_missile_list, %eax	#eax also points to the head
	
	Game_Ender:
	cmpl $0, %eax				#sees if list is empty
	je ending
	movl NEXT(%eax), %eax		#goes to the next missilie
	pushl %eax				#save callee registers
	pushl %ebx				#save callee registers
	pushl %ecx				#save callee registers	
	pushl %edx				#save register
	pushl %edi
	pushl %esi
	pushl mp1_missile_list
	call mp1_free				# deletes the missilie the headp oints to
	popl mp1_missile_list
	popl %esi
	popl %edi
	popl %edx
	popl %ecx
	popl %ebx
	popl %eax
	movl %eax, mp1_missile_list		#helps missile head point to the next missile.
	cmpl $0, mp1_missile_list		#if the linked list is not empty, keep traversing and deleting.
	jne Game_Ender
	ending:
	ret
jump_table:
	.long mp1_ioctl_startgame, mp1_ioctl_addmissile, mp1_ioctl_movexhairs, mp1_ioctl_getstatus, mp1_ioctl_endgame
	
	
	