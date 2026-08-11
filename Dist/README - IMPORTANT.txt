XeUnshackle Max - https://github.com/Klofi/XeUnshackle-Max
An independent fork of XeUnshackle by Byrom90 - https://github.com/Byrom90/XeUnshackle
THIS APP IS RELEASED AS IS.
YOU ARE RESPONSIBLE FOR WHAT YOU CHOOSE TO LOAD AND ANY NEGATIVE EFFECTS THAT MAY COME AS A RESULT.
THIS IS NOT A PERSISTENT SOFTMOD. YOUR CONSOLE WILL RETURN TO AN UNMODIFIED STATE WHEN POWERED OFF OR REBOOTED.

= Setup Instructions =
1. Setup your usb with the Xbox360BadUpdate files for your preferred game. Tutorials already exist for this.
2. Copy all the files provided in this download to your usb. Accept the prompt to replace the default.xex that 
   already exists in the BadUpdatePayload folder.
3. Insert the usb into your 360.
4. As a precaution it's recommended to disconnect your ethernet cable to prevent connections to live.
5. Launch the exploit using your chosen game.
6. Upon successful exploit this app should be loaded. You can now plug your ethernet cable back in before exiting.

= Usage Notes =
- Xex files should NOT require any patching. Anything that runs natively on RGH/JTAG consoles should work here.
- It is recommended to use a usb stick to save & store your launch.ini (Dashlaunch config) and any plugins.
  This will allow you to easily edit them without requiring access to a running exploited system.
- Plugins will be loaded the moment you exit the app. Remember to insert your ethernet before exiting when using plugins 
  requiring network access for auth. This is important for stealth server plugins.
- A key executable required by Dashlaunch is copied to your storage device. For consoles with no Hdd this is the Usb.
  This storage device must remain plugged in for Dashlaunch to function correctly.
- The files and config provided are setup to allow remote access via xbox neighborhood and connections from jrpc2 based tools.
- Auto-Start, hiding the CPUKey & DVDKey behind * characters and the boot animation's playback & volume are all controlled by an
  optional XeUnshackleConfig.txt in the BadUpdatePayload folder. Pressing Start in the app creates it for you, and every setting
  it accepts is documented here: https://github.com/Klofi/XeUnshackle-Max#features
- You can also play your own boot animation by putting a video named XeUnshackleVideo.wmv in that same folder. It has to be
  encoded in a format the console can play - there is a guide for that at the link above.

= Xbox 360 Bad Storage support =
Used for unlocking up to 2 TB internal storage. Read the official release notes here: https://fatxplorer.eaton-works.com/bad-storage/

= IMPORTANT note regarding Stealth Servers = 
Firstly stealth servers are used AT YOUR OWN RISK. 
Unlike RGH/JTAG consoles once banned there is no way to unban a retail system.
Before adding a stealth server plugin it is HIGHLY recommended to first take a dump of your nand.
The consoles MAC address is often changed as part of the initial spoofing process, THIS CHANGE IS PERSISTENT and stored within the nand config.
As an extra precaution a backup of the MAC is performed on the first launch of this app and can be found in the BadUpdatePayload folder.
Please note the app has no way of knowing if this has been changed already.

= Recommended Apps =
Simple360NandFlasher - Used to dump your nand. You'll want to avoid using the flash options it provides - https://www.consolemods.org/wiki/File:Simple_360_NAND_Flasher.7z
XexMenu 1.2 - Simple Homebrew filemanager and Game/App launcher - https://consolemods.org/wiki/File:XeXmenu_12.7z