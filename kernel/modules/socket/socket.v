module socket

import resource
import file
import errno
import socket.public as sock_pub
import socket.unix as sock_unix
import socket.netlink as sock_netlink

pub fn initialise() {}

fn socketpair_create(domain int, @type int, protocol int) ?(&resource.Resource, &resource.Resource) {
	match domain {
		sock_pub.af_unix {
			socket0, socket1 := sock_unix.create_pair(@type) ?
			return &resource.Resource(*socket0), &resource.Resource(*socket1)
		}
		/*
		sock_pub.af_netlink {
			socket0, socket1 := sock_netlink.create_pair(@type, protocol) ?
			return socket0, socket1
		}*/
		else {
			C.printf(c'socket: Unknown domain: %d\n', domain)
			errno.set(errno.einval)
			return error('')
		}
	}
}

fn socket_create(domain int, @type int, protocol int) ?&resource.Resource {
	match domain {
		sock_pub.af_unix {
			ret := sock_unix.create(@type) ?
			return ret
		}
		sock_pub.af_netlink {
			ret := sock_netlink.create(@type, protocol) ?
			return ret
		}
		else {
			C.printf(c'socket: Unknown domain: %d\n', domain)
			errno.set(errno.einval)
			return error('')
		}
	}
}

pub fn syscall_socketpair(_ voidptr, domain int, @type int, protocol int, ret &int) (u64, u64) {
	C.printf(c'\n\e[32mstrace\e[m: socketpair(%d, 0x%x, %d, 0x%llx)\n', domain, @type,
		protocol, voidptr(ret))
	defer {
		C.printf(c'\e[32mstrace\e[m: returning\n')
	}

	mut socket0, mut socket1 := socketpair_create(domain, @type, protocol) or {
		return -1, errno.get()
	}

	mut flags := int(0)
	if @type & sock_pub.sock_cloexec != 0 {
		flags |= resource.o_cloexec
	}

	unsafe {
		ret[0] = file.fdnum_create_from_resource(voidptr(0), mut socket0, flags, 0, false) or {
			return -1, errno.get()
		}

		ret[1] = file.fdnum_create_from_resource(voidptr(0), mut socket1, flags, 0, false) or {
			return -1, errno.get()
		}
	}
	return 0, 0
}

pub fn syscall_socket(_ voidptr, domain int, @type int, protocol int) (u64, u64) {
	C.printf(c'\n\e[32mstrace\e[m: socket(%d, 0x%x, %d)\n', domain, @type, protocol)
	defer {
		C.printf(c'\e[32mstrace\e[m: returning\n')
	}

	mut socket := socket_create(domain, @type, protocol) or { return -1, errno.get() }

	mut flags := int(0)
	if @type & sock_pub.sock_cloexec != 0 {
		flags |= resource.o_cloexec
	}

	ret := file.fdnum_create_from_resource(voidptr(0), mut socket, flags, 0, false) or {
		return -1, errno.get()
	}

	return u64(ret), 0
}

pub fn syscall_bind(_ voidptr, fdnum int, _addr voidptr, addrlen u64) (u64, u64) {
	C.printf(c'\n\e[32mstrace\e[m: bind(%d, 0x%llx, 0x%llx)\n', fdnum, _addr, addrlen)
	defer {
		C.printf(c'\e[32mstrace\e[m: returning\n')
	}

	mut fd := file.fd_from_fdnum(voidptr(0), fdnum) or { return -1, errno.get() }
	defer {
		fd.unref()
	}

	fd.handle.resource.bind(fd.handle, _addr, addrlen) or { return -1, errno.get() }

	return 0, 0
}

pub fn syscall_listen(_ voidptr, fdnum int, backlog int) (u64, u64) {
	C.printf(c'\n\e[32mstrace\e[m: listen(%d, %d)\n', fdnum, backlog)
	defer {
		C.printf(c'\e[32mstrace\e[m: returning\n')
	}

	mut fd := file.fd_from_fdnum(voidptr(0), fdnum) or { return -1, errno.get() }
	defer {
		fd.unref()
	}

	fd.handle.resource.listen(fd.handle, backlog) or { return -1, errno.get() }

	return 0, 0
}
