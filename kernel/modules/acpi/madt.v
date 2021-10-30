module acpi

[packed]
struct MADT {
pub:
	header               SDT
	local_contoller_addr u32
	flags                u32
	entries_begin        byte
}

[packed]
struct MADTHeader {
pub:
	id     byte
	length byte
}

[packed]
struct MADTLocalApic {
pub:
	header       MADTHeader
	processor_id byte
	apic_id      byte
	flags        u32
}

[packed]
struct MADTIoApic {
pub:
	header   MADTHeader
	apic_id  byte
	reserved byte
	address  u32
	gsib     u32
}

[packed]
struct MADTISO {
pub:
	header     MADTHeader
	bus_source byte
	irq_source byte
	gsi        u32
	flags      u16
}

[packed]
struct MADTNMI {
pub:
	header    MADTHeader
	processor byte
	flags     u16
	lint      byte
}

__global (
	madt             &MADT
	madt_local_apics []&MADTLocalApic
	madt_io_apics    []&MADTIoApic
	madt_isos        []&MADTISO
	madt_nmis        []&MADTNMI
)

fn madt_init() {
	madt := &MADT(find_sdt('APIC', 0) or { panic('System does not have a MADT') })

	mut current := u64(0)

	for {
		if current + (sizeof(MADT) - 1) >= madt.header.length {
			break
		}

		header := &MADTHeader(u64(&madt.entries_begin) + current)

		match header.id {
			0 {
				println('acpi/madt: Found local APIC #$madt_local_apics.len')
				madt_local_apics << unsafe { &MADTLocalApic(header) }
			}
			1 {
				println('acpi/madt: Found IO APIC #$madt_io_apics.len')
				madt_io_apics << unsafe { &MADTIoApic(header) }
			}
			2 {
				println('acpi/madt: Found ISO #$madt_isos.len')
				madt_isos << unsafe { &MADTISO(header) }
			}
			4 {
				println('acpi/madt: Found NMI #$madt_nmis.len')
				madt_nmis << unsafe { &MADTNMI(header) }
			}
			else {}
		}

		current += u64(header.length)
	}
}
