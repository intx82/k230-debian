# Kendryte K230-CanMV Linux boot

This repository provides *all* needed sources to boot the K230-CanMV board
to Linux user-space.

[TOC]

# Motivation

The official [Kendryte K230 SDK](https://github.com/kendryte/k230_sdk)
aims to run a real-time operating system on the "big" C908 found
in the CanMV-K230, with a small Linux system on the "little" core.

This repository on the other hand strives to provide an easier and leaner way
to install a normal Linux distribution (such as Debian, Fedora or Gentoo).
It boots a Linux kernel with support for the RISC-V Vector extension
on the *big* core and with all the RAM.

This repository also dispenses with building the RTOS
and the Busybox build root. The intent is to let *you* install *your* favorite
Linux RISC-V distribution on the root filesystem, while this repository only
builds and makes a tiny flashable image with:
* The two stages of boot loader: U-boot SPL and U-boot,
* OpenSBI, and
* the Linux kernel.

# Differences from vendor SDK

The main differences are:
* At run time:
  * Running Linux on the "big" core.
  * Support for the RISC-V Vector extension for Linux user-space.
  * Full system 512 MiB of RAM available.
  * Only 4 MiB of storage reserved for boot loader.
  * Kernel image in /boot with U-boot syslinux-style distro boot support.
  * Backported bug fixes for the onboard Ethernet adapter (RealTek 8152).
* At build time:
  * Support for non-x86-64 (incl. native RISC-V) host.
  * Support for parallel builds (vendor requires `make -j1`).
  * Support for upstream GCC cross-compilation toolchain.
  * Compatibility with up-to-date host glibc.
  * No external downloads (except for git submodules).
  * No RTOS.
  * No Buildroot/Busybox root file system (pick your own!).
  * No executable binaries without sources.

# Disclaimer

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND
CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES,
INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR
CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

# Installation

**WARNING**: Make sure that you have backed up any data from the microSD card
before you proceed. Existing data will be overwritten and permanently lost.

Note that we assume that you have a Linux or BSD desktop computer.
On other operating systems, you may need to use different tools for flashing
and accessing the serial console.

* Get a microSD card and a microSD card drive.
* Download and decompress the system image, or rebuild it yourself (see below).
* Put the microSD card into the drive.
* Check **carefully** the *correct* device node for the microSD card.
  * If you pick the wrong node, you may accidentally overwrite other data.
  * In the following example, we will assume it is called `/dev/sdz`.
* Flash the system image `sysimage-sdcard.img` onto the SD card, e.g.:
```
dd if=sysimage-sdcard.img of=/dev/sdz bs=1M
sync
```
* Open the SD card device node in a GPT partitioning tool such as `parted`:
  * Fix the Master Boot Record when asked (this is necessary because the
    system image should have been smaller than the SD card capacity).
  * Resize the "`rootfs`" (number 5) root partition.
  * Save and exit.
* Resize the `ext4` file system of the root partition, e.g.:
```
resize2fs /dev/sdz5
```
* Format new partition as `ext4`.
* Mount the root partition.
* Install a Linux RISC-V distribution on the root partition:
  * Refer to your distribution installation documentation for that part.
  * Install an NTP client such as `ntpdate`.
  * Install a network connection manager such as `network-manager`.
  * Install the OpenSSH server (optional but recommended).
  * Create a user account (if necessary).
* Unmount the root partition.
* Put the microSD card into the slot on the K230-CanMV board.
* Power the board on.

# Troubleshooting

The board has a built-in serial port available through the USB CDC ACM protocol
on the power USB-C port.

To troubleshoot, connect the board with the provided USB cable to a free port
on a Linux desktop, and attach to the serial port, e.g.:
```
# cu -l ttyACM0
```

## U-boot enviroment CRC errors

By default, the partition (number 3) to store the U-boot environment is empty,
and therefore invalid as far as U-boot is concerned. This is deliberate: we
want U-boot to use its default settings.

The error is essentially harmless. But if you want to avoid it anyway,
just save the current environment from the U-boot command line prompt.

## Kernel panic due to no init

This occurs if you flashed the image but did not install a Linux distribution.
Please recheck the installation documentation.

# Build

To rebuild the system image yourself:

* Clone this repository.
* Install the GCC cross-compiler for Linux 64-bit RISC-V:
  `riscv64-linux-gnu-gcc`.
* Install GNU/make, `xxd`, `gawk`, `sfdisk`, `fakeroot` and Python 3.
* Run `make`.

TODO: better documentation, maybe in a separate wiki page.
