implement Testfilterpush;

include "sys.m";
	sys: Sys;
	sprint: import sys;
include "draw.m";
include "filter.m";
	deflate: Filter;
include "filtertool.m";
	ft: Filtertool;

Testfilterpush: module {
	init:	fn(nil: ref Draw->Context, nil: list of string);
};

init(nil: ref Draw->Context, args: list of string)
{
	sys = load Sys Sys->PATH;
	deflate = load Filter Filter->DEFLATEPATH;
	deflate->init();
	ft = load Filtertool Filtertool->PATH;

	(nstdout, err) := ft->push(deflate, "z", sys->fildes(1), 1);
	if(err != nil)
		fail("filtertool: "+err);
	if(sys->dup(nstdout.fd, 1) < 0)
		fail(sprint("dup: %r"));

	sys->print("test 1 2 3\n");
}

fail(s: string)
{
	sys->fprint(sys->fildes(2), "%s\n", s);
	raise "fail:"+s;
}
