use strict;
use warnings;
use Test::More;

my $root = $ENV{'RAOPBRIDGE_PLUGIN_ROOT'} || 'plugin';

my @files = (
	"$root/Settings.pm",
	"$root/strings.txt",
	"$root/HTML/EN/plugins/RaopBridge/settings/basic.html",
	"$root/../application/squeeze2raop/config_raop.c",
	"$root/../application/squeeze2raop/squeeze2raop.c",
	"$root/../application/squeeze2raop/inc/squeeze2raop.h",
);

for my $file (@files) {
	open my $fh, '<', $file or die "cannot read $file: $!";
	local $/;
	my $content = <$fh>;
	close $fh;
	unlike($content, qr/resume_preroll|ResumePreroll|RESUMEPREROLL/, "$file does not expose or consume the removed RTP-resume setting");
}

done_testing;
