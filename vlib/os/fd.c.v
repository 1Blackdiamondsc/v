module os

// file descriptor based operations:

// close filedescriptor
pub fn fd_close(fd int) int {
	return C.close(fd)
}

pub fn fd_write(fd int, s string) {
	mut sp := s.str
	mut remaining := s.len
	for remaining > 0 {
		written := C.write(fd, sp, remaining)
		if written < 0 {
			return
		}
		remaining = remaining - written
		sp = unsafe { sp + written }
	}
}

// read from filedescriptor, block until data
pub fn fd_slurp(fd int) []string {
	mut res := []string{}
	for {
		s, b := fd_read(fd, 4096)
		if b <= 0 {
			break
		}
		res << s
	}
	return res
}

// read from filedescriptor, don't block
// return [bytestring,nrbytes]
pub fn fd_read(fd int, maxbytes int) (string, int) {
	unsafe {
		mut buf := malloc(maxbytes)
		nbytes := C.read(fd, buf, maxbytes)
		if nbytes < 0 {
			free(buf)
			return '', nbytes
		}
		buf[nbytes] = 0
		return tos(buf, nbytes), nbytes
	}
}
