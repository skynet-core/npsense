# NPSense
## Predator-Sense like Linux's service for controlling Acer gaming laptops fans speed
All contributors 👨‍💻👩‍💻 are welcome. Donate💸💳 and tips☕ are greatly acceptable

# Warning!
This project is in Beta now! There are no configs except for Acer Predator P515-15. 
Please, use it carefully...

## Why 🤔

I am a Linux fan. I like it a lot, and found that I hate Windows a bit because of many reasons I wouldn't discuss 😅
But since time I've bought `Acer Predator Triton 500` I was struggle to understand why I can't force my fans
work with any tools from well-known list. I've tried may of them, I even found [nbfc](https://github.com/hirschmann/nbfc) 
project which you may find more complete and useful then this one, 
but I faced into some troubles when was configuring it, so I decided to 
deep dive into embedded development world a bit (yeah, far from real IoT stuff, but anyway connected a bit) 😎
So I'd decided to build a straightforward in configuration service which just works and works well, but 
keeping in mind idea of more wide set of sweat tool for configuration and monitoring temp, speed and manual control.
I hope this project will help many Linux users which had bad luck to buy Acer gaming laptop without cooling software
support on our lovely Linux! Let's make it C🥶LD!

## How to build

        cd /tmp && git clone git@github.com:skynet-core/npsense.git
        cd ./npsense && nimble build -d:release
        nimble setup --configName:AcerP515-51   // install files into your system
        nimble purge                            // uninstall files from system

## TODO list

- [x] Temperature zones and fans speed level switching (ver 0.5.0)
- [x] Systemd sleep hook via SIGTSTP and SIGCONT signals with switching to BIOS auto mode
- [x] Systemd unit file (ver 0.6.0)
- [x] Installation with nimble
- [ ] Simple FAQ 
- [ ] Apt, Rpm packages (ver 1.0.0)
- [ ] command-line front-end client (ver 1.0.0)
- [ ] Snap, Flatpak bundles (ver 1.1.0)
- [ ] Support for different from systemd init systems (ver 1.5.0)
- [ ] Implement communication via `/dev/port` as an option for safety reasons (ver 2.0.0)
- [ ] termgui font-end client (ver 2.5.0)
- [ ] Qt front-end client (ver 3.0.0)
- [ ] Mobile GUI and remote control via mobile application (gRPC) (ver 3.5.0)