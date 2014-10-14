/* tuxctl-ioctl.c
 *
 * Driver (skeleton) for the mp2 tuxcontrollers for ECE391 at UIUC.
 *
 * Mark Murphy 2006
 * Andrew Ofisher 2007
 * Steve Lumetta 12-13 Sep 2009
 * Puskar Naha 2013
 */

#include <asm/current.h>
#include <asm/uaccess.h>

#include <linux/kernel.h>
#include <linux/init.h>
#include <linux/module.h>
#include <linux/fs.h>
#include <linux/sched.h>
#include <linux/file.h>
#include <linux/miscdevice.h>
#include <linux/kdev_t.h>
#include <linux/tty.h>
#include <linux/spinlock.h>

#include "tuxctl-ld.h"
#include "tuxctl-ioctl.h"
#include "mtcp.h"

#define debug(str, ...) \
	printk(KERN_DEBUG "%s: " str, __FUNCTION__, ## __VA_ARGS__)
/* local function declarations*/
int inittux(struct tty_struct* tty);
int set_led(struct tty_struct* tty, unsigned long arg);
int set_buttons(struct tty_struct* tty, unsigned long arg);
int reset_tux(struct tty_struct* tty);
unsigned long hexdriver(unsigned long val, unsigned long dec);
/*location file scope variables*/
uint8_t button_packet[2]; //handles the b and c packets.
uint8_t button[1];	//Used to handle button packets and condenses the two into 1 byte.
int sig;		//sig to prevent cmd spamming.
unsigned long LED; //Holds the LED value so we can correctly output the clock despite resets.
/************************ Protocol Implementation *************************/

/* tuxctl_handle_packet()
 * IMPORTANT : Read the header for tuxctl_ldisc_data_callback() in 
 * tuxctl-ld.c. It calls this function, so all warnings there apply 
 * here as well.
 */
 /* 
 * tuxctl_handle_packet()
 *   DESCRIPTION: Read the header for tuxctl_ldisc_data_callback() in 
 * tuxctl-ld.c. It calls this function, so all warnings there apply. Recieves signals from device.
 * here as well. Opcode sent in first packet.
 *   OUTPUTS: none
 *   RETURN VALUE: none
 *   SIDE EFFECTS: sets up packets for other functions to use, or will call other functions.
 */
void tuxctl_handle_packet (struct tty_struct* tty, unsigned char* packet)
{
    unsigned a, b, c;
    a = packet[0]; /* Avoid printk() sign extending the 8-bit */
    b = packet[1]; /* values when printing them. */
    c = packet[2];
	
	//determines what the opcode is trying to do
	switch(a)
	{
		case(MTCP_ACK):
			sig = 0;
			return;
		case(MTCP_RESET):
			reset_tux(tty); 
			return;
		case(MTCP_ERROR):
			
			return;
		case(MTCP_BIOC_EVENT):
			button_packet[0] = b;
			button_packet[1] = c;
			return;
		default:
			return;
	}
}
 /* 
 * reset_tux
 *   DESCRIPTION: called by RESET procotcol and will initiate MTCP_BIOC_ON to turn on button receiving, MTCP_LED_USR to set LED in user mode.
	INPUTS: tty
 *   OUTPUTS: none
 *   RETURN VALUE: -EINVAL to do nothing and 0 to show LED.
 *   SIDE EFFECTS: none
 */
int reset_tux(struct tty_struct* tty)
{
	char init_bic = MTCP_BIOC_ON;
	char init_led = MTCP_LED_USR;
	
	tuxctl_ldisc_put(tty, &init_bic, 1);	//sends the above two signals to the tux controller.
	tuxctl_ldisc_put(tty, &init_led, 1);
	if (sig == 1)	//Don't do anything if sig is 1, because someone is obviously spamming a button.
		return -EINVAL;	
	else//show our correct LED.
	{
		sig = 1;
		set_led(tty,LED);	
		return 0;
	}
}
/* 
 * inittux
 *   DESCRIPTION: initializes the game!
 *   INPUTS:tty struct
 *   OUTPUTS: none
 *   RETURN VALUE: 0.
 *   SIDE EFFECTS: initializes the game. Similar functionality to reset, only we don't worry about sig conditions.
 */
int inittux(struct tty_struct* tty)
{
	char init_bic = MTCP_BIOC_ON;
	char init_led = MTCP_LED_USR;
	sig = 1;
	tuxctl_ldisc_put(tty, &init_bic, 1);
	tuxctl_ldisc_put(tty, &init_led, 1);
	LED = 0XF0FF0000; //Turns off all LEDs.
	
	return 0;
}
/* 
 * set_led
 *   DESCRIPTION: creates the led signal that will display the right thing!
 *   INPUTS:tty, and LED packet in arg.
 *   OUTPUTS: none
 *   RETURN VALUE: 0.
 *   SIDE EFFECTS: updates currently LED display and global..
 */
int set_led(struct tty_struct* tty, unsigned long arg)
{
	unsigned long init0, init1, init2, init3;
	unsigned long argVal, led_temp, dec_temp,bufCount;
	uint8_t buffer[6], argValShifted;
	
	buffer[0] = MTCP_LED_SET;	//Set our LED to the following.
	
	led_temp = (arg & 0x000F0000); //Figure out which led's are turned on
	led_temp = led_temp >>16;	//Led_temp has which leds are turned on
	bufCount = 0;	//start at 0.
	buffer[1] = led_temp;	//which LED's are turned on.
	argVal = arg;	//holds argument, or LED information.

	if(led_temp&0x01)	//See if first led is turned on
	{
		bufCount++;		//incr buf count.
		init0 = arg & 0x0000000F;	//finds value of what to show
		dec_temp = (arg>>24)&0x01;	//if the corresponding decimal point is on
		argValShifted = (hexdriver(init0,dec_temp));	//maps the value of what to display to something the led can interpret.
		buffer[2] = argValShifted&0xFF;	//puts led readable value into buffer.
	}
	if(led_temp&0x02)
	{	
		bufCount++;
		init1 = (arg>>4) & 0x0000000F;
		dec_temp = (arg>>25)&0x01;
		argValShifted = (hexdriver(init1,dec_temp));
		buffer[3] = argValShifted&0xFF;;
	}
	if(led_temp&0x04)
	{
		bufCount++;
		init2 = (arg>>8) & 0x0000000F;
		dec_temp = (arg>>26)&0x01;
		argValShifted = (hexdriver(init2,dec_temp));
		buffer[4] = argValShifted&0xFF;;
	}
	if(led_temp&0x08)
	{
		bufCount++;
		init3 = (arg>>12) & 0x0000000F;
		dec_temp = (arg>>27)&0x01;
		argValShifted = (hexdriver(init3,dec_temp));
		buffer[5] = argValShifted&0xFF;
	}
	if(sig == 1)	
		return 0;
	else
		sig =1;
		tuxctl_ldisc_put(tty, buffer, 2+bufCount);	//sends buffer to device for led to display.
		LED= arg; //set global variable.
	return 0;
}
/* 
 * set_button
 *   DESCRIPTION: creates button packet and sends to be interpretted.
 *   INPUTS:tty struct, arg
 *   OUTPUTS: none
 *   RETURN VALUE: 0.
 *   SIDE EFFECTS: screen will abide by the controls.
 */
int set_buttons(struct tty_struct* tty, unsigned long arg)
{
	uint8_t button[1];
	unsigned long* to = (unsigned long *) arg;
	if (to == (NULL))
		return -EINVA;
	button[0]= ((button_packet[0]&0x0F) | ((button_packet[1]<<4)&0xF0));
	
	copy_to_user (to, button, 1); //sends to the user
	return 0;
}
/* 
 * inittux
 *   DESCRIPTION: initializes the game!
 *   INPUTS:tty struct
 *   OUTPUTS: none
 *   RETURN VALUE: 0.
 *   SIDE EFFECTS: initializes the game. Similar functionality to reset, only we don't worry about sig conditions.
 */
unsigned long hexdriver(unsigned long val, unsigned long dec)
{
	if(!dec)
	{
		switch(val)
		{
			case (0x0):
				return val = 0x000000E7;
			case (0x1):
				return val = 0x00000006;
			case (0x2):
				return val = 0x000000CB;
			case (0x3):
				return val = 0x0000008F;
			case (0x4):
				return val = 0x0000002E;
			case (0x5):
				return val = 0x000000AD;
			case (0x6):
				return val = 0x000000ED;
			case (0x7):
				return val = 0x00000086;
			case (0x8): 
				return val = 0x000000EF;
			case (0x9):
				return val = 0x000000AE;
			case (0xA):
				return val = 0x000000EE;
			case (0xB):
				return val = 0x0000006D;
			case (0xC):
				return val = 0x000000E1;
			case (0xD):
				return val = 0x0000004F;
			case (0xE):
				return val = 0x000000E9;
			case (0xF):
				return val= 0x000000E8;
			default:
				return 0x0;
		}
	}
	else
	{
		switch(val)
		{
			case (0x0):
				return val = 0x000000F7;
			case (0x1):
				return val = 0x00000016;
			case (0x2):
				return val = 0x000000DB;
			case (0x3):
				return val = 0x0000009F;
			case (0x4):
				return val = 0x0000003E;
			case (0x5):
				return val = 0x000000BD;
			case (0x6):
				return val = 0x000000FD;
			case (0x7):
				return val = 0x00000096;
			case (0x8): 
				return val = 0x000000FF;
			case (0x9):
				return val = 0x000000BE;
			case (0xA):
				return val = 0x000000FE;
			case (0xB):
				return val = 0x0000007D;
			case (0xC):
				return val = 0x000000F1;
			case (0xD):
				return val = 0x0000005F;
			case (0xE):
				return val = 0x000000F9;
			case (0xF):
				return val= 0x000000F8;
			default:
				return 0x0;
		}
	}
}

/******** IMPORTANT NOTE: READ THIS BEFORE IMPLEMENTING THE IOCTLS ************
 *                                                                            *
 * The ioctls should not spend any time waiting for responses to the commands *
 * they send to the controller. The data is sent over the serial line at      *
 * 9600 BAUD. At this rate, a byte takes approximately 1 millisecond to       *
 * transmit; this means that there will be about 9 milliseconds between       *
 * the time you request that the low-level serial driver send the             *
 * 6-byte SET_LEDS packet and the time the 3-byte ACK packet finishes         *
 * arriving. This is far too long a time for a system call to take. The       *
 * ioctls should return immediately with success if their parameters are      *
 * valid.                                                                     *
 *                                                                            *
 ******************************************************************************//* 
 * tuxctl_ioclt
 *   DESCRIPTION: implements our IOCTLS for 3 specific commands. Sends commands to the device.
 *   INPUTS:tty, file, command, arg sociated with command.
 *   OUTPUTS: none
 *   RETURN VALUE: function calls, else -EINVAL.
 *   SIDE EFFECTS: set values to global varaiables.
 */
int 
tuxctl_ioctl (struct tty_struct* tty, struct file* file, 
	      unsigned cmd, unsigned long arg)
{
    switch (cmd) {
	//initializes game.
	case TUX_INIT:
		return inittux(tty); 
	//buttons are going to be interpretted.
	case TUX_BUTTONS:
		return set_buttons(tty, arg); 
	//
	case TUX_SET_LED:
		return set_led(tty,arg) ;
	default:
	    return -EINVAL;
    }
}
