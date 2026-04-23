# WISPR3
WISPR3

Firmware binary files (an other formats) can be found at [https://github.com/embeddedocean/wispr3_nrs/tree/Release](https://github.com/embeddedocean/wispr3/tree/main/Release)

## Bootloader:
The bootloader executes at startup and either updates the application firmware or executes the application firmware.

If a binary file named **`wispr3.bin`** is found on **SD card 1**,
the bootloader will automatically update the system firmware. 

After the new firmmware is flashed, the bootloader will remove the bin file from the SD card.

On subsequent startups, if no binary file is found on the the SD card, the bootloader will start the **wispr3** application.

To use the bootloader, first flash the bootloaded.

## To flash the system bootloader:
Open a command prompt in Atmel Studio using tools->Command Prompt.
Go to the Release directory in the project.
Then type: 

 ```sh
   atprogram -t atmelice -i SWD -d ATSAMD51J20A program -f wispr3_bl.elf
   ```

Now copy the application **wispr3.bin** to SD card 1.

The next time the system is reset or rebooted, the bootloader will flash the application to the proper memory location.

## Using the system without the bootloader:

Without the bootloader, the system must be flashed to boot directly in to the application. 

In this case flash the application **wispr3_nobl.bin** directly using: 

 ```sh
   atprogram -t atmelice -i SWD -d ATSAMD51J20A program -f wispr3_nobl.elf
   ```

Without the bootloader the application binary must be biult with the proper memory space definitions.