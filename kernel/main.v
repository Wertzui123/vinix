module main

import lib
import lib.stubs // unused, but needed for C function stubs
import memory
import stivale2
import acpi
import x86.gdt
import x86.idt
import x86.isr
import x86.smp
import initramfs
import fs
import sched
import stat
import dev.console
import userland
import kprint
import pipe
import futex
import pci
import dev.ata
import dev.nvme
import dev.streams
import dev.random
import syscall.table

import socket

fn C._vinit(argc int, argv voidptr)

fn kmain_thread(stivale2_struct &stivale2.Struct) {
	table.init_syscall_table()
	socket.initialise()
	pipe.initialise()
	futex.initialise()
	fs.initialise()
	pci.initialise()

	fs.mount(vfs_root, '', '/', 'tmpfs') or {}
	fs.create(vfs_root, '/dev', 0o644 | stat.ifdir) or {}
	fs.mount(vfs_root, '', '/dev', 'devtmpfs') or {}

	modules_tag := &stivale2.ModulesTag(stivale2.get_tag(stivale2_struct, stivale2.modules_id) or {
		panic('Stivale2 modules tag missing')
	})

	initramfs.init(modules_tag)

	streams.initialise()
	console.initialise()
	ata.initialise()
	nvme.initialise()
	random.initialise()

	userland.start_program(false, vfs_root, '/sbin/init', ['/sbin/init'],
							['HOME=/root',
							'TERM=linux',
							'PATH=/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin'],
							'/dev/console', '/dev/console', '/dev/console') or {
		panic('Could not start init process')
	}

	sched.dequeue_and_die()
}

pub fn main() {
	kmain(voidptr(0))
}

pub fn kmain(stivale2_struct &stivale2.Struct) {
	// Initialize the earliest arch structures.
	gdt.initialise()
	idt.initialise()
	isr.initialise()

	// Init terminal
	stivale2.terminal_init(stivale2_struct)

	// We're alive
	kprint.kprint(c'Welcome to Vinix\n\n')

	// Initialize the memory allocator.
	memmap_tag := &stivale2.MemmapTag(stivale2.get_tag(stivale2_struct, stivale2.memmap_id) or {
		lib.kpanic(voidptr(0), c'Stivale2 memmap tag missing')
	})

	memory.pmm_init(memmap_tag)

	// Call Vinit to initialise the runtime
	C._vinit(0, 0)

	// a dummy call to avoid V warning about an unused `stubs` module
	_ := stubs.toupper(0)

	memory.vmm_init(memmap_tag)

	// ACPI init
	rsdp_tag := &stivale2.RSDPTag(stivale2.get_tag(stivale2_struct, stivale2.rsdp_id) or {
		panic('Stivale2 RSDP tag missing')
	})

	acpi.init(&acpi.RSDP(rsdp_tag.rsdp))

	smp_tag := &stivale2.SMPTag(stivale2.get_tag(stivale2_struct, stivale2.smp_id) or {
		panic('Stivale2 SMP tag missing')
	})

	smp.initialise(smp_tag)

	sched.initialise()

	go kmain_thread(stivale2_struct)

	sched.await()
}
