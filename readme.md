# SemitoneBootQuiz

A "Boot Sector Game" written in x86-16 Assembly, assembled with [fasm](https://flatassembler.net/).

## The Game

The game generates two pseudo-random tones, and the player has to input the amount of semitone steps between the two. If the player guessed correctly, the game is won

## Versions

The release includes 3 versions, which differ in what happens when the game is won:

- do_nothing: Ends in an endless loop of nothingness
- reboot: Uses `int 18h` to reboot the computer. This should result in the computer booting from the next device configured in the BIOS boot order.
- rpt_forever: Gets two new tones and starts the game again (recommended version)

## Starting The Game

To play the game, you need to write the boot sector onto something (floppy disk is recommended). You can use programs like [RawWriteWin](http://freshmeat.sourceforge.net/projects/rawwriteforwindows/) or [Roadkil's Sector Editor](https://roadkil.net/program.php?ProgramID=24&Action=NewOSID) to write the boot sector onto a floppy.

When done, you only need to boot from the floppy disk.

You can also run it in DOSBox by using the `boot` command (For example `boot D:\Bootsectors\rpt_forever.bin`)

## System requirements

- PC Speaker
- 8086/8088 CPU
- VGA mode 03h capable graphics adapter
- Floppy drive



