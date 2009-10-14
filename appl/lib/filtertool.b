implement Filtertool;

include "sys.m";
	sys: Sys;
	sprint: import sys;
include "filter.m";
include "util0.m";
	util: Util0;
	rev, warn, kill, min: import util;
include "filtertool.m";

# xxx should probably replace the caller's fd with a file2chan-opened file.
# so on error in filter we can make the caller's reads fail with sensible error message.

mods()
{
	if(sys != nil)
		return;
	sys = load Sys Sys->PATH;
	util = load Util0 Util0->PATH;
	util->init();
}

push(f: Filter, params: string, fd: ref Sys->FD, out: int): (ref Sys->FD, string)
{
	mods();

	if(sys->pipe(fds := array[2] of ref Sys->FD) < 0)
		return (nil, sprint("pipe: %r"));

	pidc := chan of int;
	if(out)
		spawn tunnel(f, params, fds[1], fd, pidc);
	else
		spawn tunnel(f, params, fd, fds[1], pidc);
	<-pidc;
	return (fds[0], nil);
}

tunnel(f: Filter, params: string, in, out: ref Sys->FD, pidc: chan of int)
{
	pidc <-= sys->pctl(Sys->NEWFD, in.fd::out.fd::2::nil);
	in = sys->fildes(in.fd);
	out = sys->fildes(out.fd);

	rqc := f->start(params);
	for(;;) {
		pick rq := <-rqc {
		Start =>
			;
		Fill =>
			n := sys->read(in, rq.buf, len rq.buf);
			rq.reply <-= n;
			if(n < 0) {
				warn(sprint("read: %r"));
				return;
			}
		Result =>
			if(sys->write(out, rq.buf, len rq.buf) != len rq.buf) {
				warn(sprint("write: %r"));
				return;
			}
			rq.reply <-= 0;
		Finished =>
			if(len rq.buf != 0)
				warn(sprint("%d leftover bytes", len rq.buf));
			return;
		Info =>
			# rq.msg
			;
		Error =>
			warn("error: "+rq.e);
			return;
		}
	}
}

convert(f: Filter, params: string, d: array of byte): (array of byte, string)
{
	mods();

	c := f->start(params);
	pid: int;
	pick req0 := <-c {
	Start =>
		pid = req0.pid;
	* =>
		return (nil, "bad filter");
	}

	o := 0;
	l: list of array of byte;
	nb := 0;
filter:
	for(;;)
	pick req := <-c {
	Start =>
		kill(pid);
		return (nil, "bad filter");
	Fill =>
		give := min(len req.buf, len d-o);
		req.buf[:] = d[o:o+give];
		o += give;
		req.reply <-= give;
		
	Result =>
		buf := array[len req.buf] of byte;
		buf[:] = req.buf;
		l = buf::l;
		nb += len buf;
		req.reply <-= 0;

	Info =>
		;

	Finished =>
		if(len req.buf != 0)
			return (nil, "data left");
		break filter;

	Error =>
		kill(pid);
		return (nil, "filter: "+req.e);

	* =>
		return (nil, "filter: missing case");
	}

	buf := array[nb] of byte;
	o = 0;
	for(l = rev(l); l != nil; l = tl l) {
		buf[o:] = hd l;
		o += len hd l;
	}
	if(o != len buf)
		return (nil, "internal convert error");
	return (buf, nil);
}
