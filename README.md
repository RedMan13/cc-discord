# ComputerCraft-Discord
an entire discord client made inside lua

## important notes
this is still in development and will not properly work on most accounts in more then one server

also, your token is stored in a plan text file. so i would advise you NEVER use this on a public server

## todo
- [ ] guild switching
- [ ] guild listing
- [ ] better channel switching
- [ ] edit message
- [ ] delete message
- [ ] react to message
- [ ] reply to message
- [ ] better message delete
- [ ] zlib-stream compresion on the websocket
- [ ] better security?
- [ ] 2fa support

## installation
1. first create the computers folder by creating a file in the computer, you can do so with `edit fileName` and then clicking "save".
2. then go to `{gameRoot}/saves/{yourSaveName}/computercraft/computer/{computerId}`, you can go to the game root by opening your resource pack folder then backing out by one, you can also get the computer id by running `id` on the computer.
3. now download and unzip the files from this repo into that folder making sure that `startup.lua` is still visible from inside the computer folder and NOT in a subfolder. or, if you have the gh cli installed, run `gh repo clone {computerId}` inside `{gameRoot}/saves/{yourSaveName}/computercraft/computer` in your irl comuters terminal
4. click start on the computer and login.

note that you can replace `computer/{computerId}` with `disk/{diskId}` although idk how to get disk id :/
