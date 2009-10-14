Filtertool: module
{
	PATH:	con "/dis/lib/filtertool.dis";

	push:		fn(f: Filter, params: string, fd: ref Sys->FD, out: int): (ref Sys->FD, string);
	convert:	fn(f: Filter, params: string, buf: array of byte): (array of byte, string);
};
