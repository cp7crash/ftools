# ftools

Random (sometimes useful) tools for (mostly) windows that (probably) shouldn't get lost.

| Tool                            | Platform     | Purpose                                                           | Exists Because                                                           |
| ------------------------------- | ------------ | ----------------------------------------------------------------- | ------------------------------------------------------------------------ |
| [seftup](seftup.cmd)            | Windows XP+  | Adds these tools to your path                                     | They're much more useful available globally                              |
| [x](x.cmd)                      | Windows 3.1+ | Close the current terminal with two key strokes                   | The automation journey had to start somewhere                            |
| [ascii_chars](ascii_chars.xlsx) | Excel 2007+  | A table of ascii characters and their codes                       | It used to be hard to find in VBA                                        |
| [ls](x.cmd)                     | Windows 3.1+ | Provides an alias for dir                                         | I'm always forgetting which platform I'm on                              |
| [unsvn](unsvn.cmd)              | Windows XP+  | Deep cleans .svn directories from a folder                        | Convincing people infrastructure-as-code is a thing was painful at first |
| [pingalot](pingalot.cmd)        | Windows XP+  | Ping a host with a range of buffer sizes                          | A firmware bug in juniper routers nearly scuppered openHIVE              |
| [ftlib](ftlib.cmd)              | Windows XP+  | Provides some useful re-usable functions for batch scripts        | Many batch scripts share some behaviors                                  |
| [shrinkpath](shrinkpath)        | Windows XP+  | Remove non-existent and shorten path var                          | Because a 1024 char path can be a problem                                |
| [bren](bren.cmd)                | Windows 10+  | Add a pre/suffix to a collection of files                         | Adding many web resources to a Power Apps solution can be painful        |
| [git-shame](gitshame.ps1)       | Windows 7+   | Find git repos with uncommitted changes, get appropriately shamed | One computer for the day, another by night                               |
| [snk-peek](snk-peek.ps1)        | Windows 7+   | See inside Strong Name Keys                                       | Need to see whether we have pub/ private keys in .snk                    |

## using lib.cmd

```
call lib.cmd strlen "Hello World"
```

All tools [@cp7crash](https://www.github.com/cp7crash); inspiration from many.
Actively trying to do something about most of this list making me feel old 😞

[![License: CCL](https://licensebuttons.net/l/zero/1.0/80x15.png)](http://creativecommons.org/publicdomain/zero/1.0/)
