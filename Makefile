unexport CC
unexport CXX
unexport CFLAGS
unexport CXXFLAGS
unexport LDFLAGS
unexport MAKEFLAGS

.PHONY: all
all: vinix.iso

QEMUFLAGS = -M q35,smm=off -m 8G -cdrom vinix.iso -serial stdio

.PHONY: run-kvm
run-kvm: vinix.iso
	qemu-system-x86_64 -enable-kvm -cpu host $(QEMUFLAGS) -smp 4

.PHONY: run-hvf
run-hvf: vinix.iso
	qemu-system-x86_64 -accel hvf -cpu host $(QEMUFLAGS) -smp 4

.PHONY: run
run: vinix.iso
	qemu-system-x86_64 $(QEMUFLAGS) -no-shutdown -no-reboot -d int -smp 1

.PHONY: distro
distro:
	mkdir -p build 3rdparty
	cd build && [ -f bootstrap.link ] || xbstrap init ..
	cd build && xbstrap install -u --all

.PHONY: kernel
kernel:
	cd build && xbstrap install --rebuild kernel

.PHONY: init
init:
	cd build && xbstrap install --rebuild init

.PHONY: base-files
base-files:
	cd build && xbstrap install --rebuild base-files

vinix.iso: kernel init base-files
	cd build && xbstrap run make-iso
	mv build/vinix.iso ./

.PHONY: clean
clean:
	$(MAKE) -C kernel clean
	rm -f init/init
	rm -f vinix.iso

.PHONY: distclean
distclean: clean
	rm -rf 3rdparty build initramfs.tar.gz pack
	rm -f kernel/*.xbstrap init/*.xbstrap base-files/*.xbstrap
